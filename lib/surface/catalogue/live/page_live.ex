defmodule Surface.Catalogue.PageLive do
  use Surface.LiveView

  alias Surface.Catalogue.{Playground, Util, ExampleLive, PlaygroundLive, Markdown}
  alias Surface.Catalogue.Components.{ComponentInfo, ComponentTree, PlaygroundTools}
  alias Surface.Components.LivePatch

  @playground_default_height "160px"
  @playground_default_width "100%"

  data component_name, :string, default: nil
  data component_module, :module
  data has_example?, :boolean
  data has_playground?, :boolean
  data components, :map, default: %{}
  data action, :string
  data examples_and_playgrounds, :map, default: %{}
  data examples, :list, default: []
  data playgrounds, :list, default: []
  data __window_id__, :string, default: nil
  data playground_height, :string, default: @playground_default_height
  data playground_width, :string, default: @playground_default_width
  data playground_tools_initialized?, :boolean, default: false
  data single_catalogue?, :boolean, default: false
  data home_view, :module, default: nil

  def mount(params, session, socket) do
    socket =
      if connected?(socket) do
        {components, examples_and_playgrounds} = Util.get_components_info()

        catalogues = Application.get_env(:surface_catalogue, :catalogues) || []
        home_view = Application.get_env(:surface_catalogue, :home_view)
        single_catalogue? = length(catalogues) == 1

        socket
        |> maybe_assign_window_id(params, session)
        |> assign(:components, components)
        |> assign(:single_catalogue?, single_catalogue?)
        |> assign(:home_view, home_view)
        |> assign(:examples_and_playgrounds, examples_and_playgrounds)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      if params["component"] != socket.assigns.component_name do
        assign(socket, :playground_tools_initialized?, false)
      else
        socket
      end

    socket =
      socket
      |> assign(:action, params["action"] || "docs")
      |> assign_component_info(params["component"])

    {:noreply, socket}
  end

  def handle_info({:playground_tools_initialized, subject}, socket) do
    if subject == socket.assigns.component_module do
      {:noreply, assign(socket, :playground_tools_initialized?, true)}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="position: relative;">
      <div class="sidebar-bg"/>
      <div class="container is-fullhd">
        <section class="main-content columns">
          <ComponentTree
            id="component-tree"
            components={{ @components }}
            selected_component={{ @component_name }}
            single_catalogue?={{ @single_catalogue? }}
          />
          <div class="container column" style="background-color: #fff; min-height: 500px;">
            <div :if={{ !@component_module and @home_view }}>
              {{ live_render(@socket, @home_view, id: "home_view") }}
            </div>
            <div :if={{ !@component_module and !@home_view}} class="columns is-centered is-vcentered is-mobile" style="height: 300px">
              <div class="column is-narrow has-text-centered subtitle has-text-grey">
                No component selected
              </div>
            </div>
            <If condition={{ @component_module }}>
              <div class="component tabs is-medium">
                <ul>
                  <li class={{ "is-active": @action == "docs" }}>
                    <LivePatch to={{ path_to(@socket, __MODULE__, @component_name, :docs) }}>
                      <span class="icon is-small"><i class="far fa-file-alt" aria-hidden="true"></i></span>
                      <span>Docs &amp; API</span>
                    </LivePatch>
                  </li>
                  <li :if={{ @has_example? }} class={{ "is-active": @action == "example" }}>
                    <LivePatch to={{ path_to(@socket, __MODULE__, @component_name, :example)}}>
                      <span class="icon is-small"><i class="fas fa-image" aria-hidden="true"></i></span>
                      <span>Examples</span>
                    </LivePatch>
                  </li>
                  <li :if={{ @has_playground? }} class={{ "is-active": @action == "playground" }}>
                    <LivePatch to={{ path_to(@socket, __MODULE__, @component_name, :playground)}}>
                      <span class="icon is-small"><i class="far fa-play-circle" aria-hidden="true"></i></span>
                      <span id="playground-tab-label" phx-update="ignore">Playground</span>
                    </LivePatch>
                  </li>
                </ul>
              </div>
              <div class="section">
                <div :show={{ @action == "docs" }}>
                  <ComponentInfo module={{ @component_module }} />
                </div>
                <div :show={{ @action == "example" }}>
                  <For each={{ {example, index} <- Enum.with_index(@examples, 1) }}>
                    <h3
                      :show={{ example.title }}
                      id="example-{{index}}"
                      class={{ "example-title title is-4 is-spaced", "is-marginless": example.doc != "" }}
                    >
                      <a href="#example-{{index}}">#</a> {{ example.title }}
                    </h3>
                    <div :if={{ example.doc != "" }} style="padding-bottom: 1.5rem;">
                      {{ example.doc |> Markdown.to_html() }}
                    </div>
                    <div :show={{ @action == "example" }} class="Example {{example.direction}}">
                      <div class="demo" style="width: {{example.demo_perc}}%">
                        <iframe
                          scrolling={{ if example.scrolling, do: "yes", else: "no"}}
                          id="example-iframe-{{index}}"
                          src={{ path_to(@socket, ExampleLive, example.module_name, __window_id__: @__window_id__) }}
                          style="overflow-y: hidden; width: 100%; height: {{ example.height }};"
                          frameborder="0"
                          phx-hook="IframeBody"
                        />
                      </div>
                      <div class="code" phx-update="ignore" style="width: {{example.code_perc}}%">
                        <pre class="language-surface">
                          <code class="content language-surface" phx-hook="Highlight" id="example-code-{{index}}">
    {{ example.code }}</code>
                        </pre>
                      </div>
                    </div>
                  </For>
                  <div :show={{ !connected?(@socket) }} class="container">
                    {{ loading("Loading live #{@action}...") }}
                  </div>
                </div>
                <div :show={{ @action == "playground" }}>
                  <div :show={{ @playground_tools_initialized? }}>
                    <iframe
                      id="playground-iframe"
                      :if={{ @has_playground? }}
                      src={{ path_to(@socket, PlaygroundLive, Enum.at(@playgrounds, 0), __window_id__: @__window_id__) }}
                      style="height: {{ @playground_height }}; width: {{ @playground_width }};"
                      frameborder="0"
                      phx-hook="IframeBody"
                    />
                    <div style="padding-top: 1.5rem;">
                      <PlaygroundTools id="playground_tools" session={{ %{"__window_id__" => @__window_id__} }} />
                    </div>
                  </div>
                  <div :show={{ !@playground_tools_initialized? }} class="container">
                    {{ loading("Loading live #{@action}...") }}
                  </div>
                </div>
              </div>
            </If>
          </div>
        </section>
      </div>
    </div>
    """
  end

  def handle_event("playground_resize", %{"height" => height, "width" => width}, socket) do
    {:noreply, assign(socket, playground_height: height, playground_width: width)}
  end

  defp assign_component_info(socket, component_name) do
    component_module = get_component_by_name(component_name)
    examples_and_playgrounds = socket.assigns.examples_and_playgrounds

    examples = Util.get_examples(component_module, examples_and_playgrounds)
    playgrounds = Util.get_playgrounds(component_module, examples_and_playgrounds)
    playground = Enum.at(playgrounds, 0)

    playground_height =
      if playground do
        playground_module = Module.safe_concat([playground])
        playground_config = Surface.Catalogue.get_config(playground_module)
        Keyword.fetch!(playground_config, :height)
      end

    socket =
      if component_name != socket.assigns.component_name do
        socket
        |> assign(:playground_height, playground_height || @playground_default_height)
        |> assign(:playground_width, @playground_default_width)
      else
        socket
      end

    socket
    |> assign(:component_name, component_name)
    |> assign(:component_module, component_module)
    |> assign(:has_example?, examples != [])
    |> assign(:has_playground?, playgrounds != [])
    |> assign(:examples, examples)
    |> assign(:playgrounds, playgrounds)
  end

  defp maybe_assign_window_id(socket, params, session) do
    if connected?(socket) do
      window_id = Playground.get_window_id(session, params)
      assign(socket, :__window_id__, window_id)
    else
      socket
    end
  end

  defp get_component_by_name(name) do
    name && Module.safe_concat([name])
  end

  defp path_to(socket, live_view, component_name, action) when is_atom(action) do
    socket.router.__helpers__().live_path(socket, live_view, component_name, action)
  end

  defp path_to(socket, live_view, component_name, params) when is_list(params) do
    socket.router.__helpers__().live_path(socket, live_view, component_name, params)
  end

  defp loading(message) do
    assigns = %{}

    ~H"""
    <div class="columns is-centered is-vcentered is-mobile" style="height: 300px">
      <div class="column is-narrow has-text-centered subtitle has-text-grey">
        {{ message }}
      </div>
    </div>
    """
  end
end
