defmodule Surface.Catalogue.PageLive do
  use Surface.LiveView

  alias Surface.Catalogue.{Playground, Util, ExampleLive, PlaygroundLive}
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
  data playground_height, :string, default: "150px"
  data playground_width, :string, default: "100%"

  def mount(params, session, socket) do
    socket =
      if connected?(socket) do
        {components, examples_and_playgrounds} = Util.get_components_info()

        socket
        |> maybe_assign_window_id(params, session)
        |> assign(:components, components)
        |> assign(:examples_and_playgrounds, examples_and_playgrounds)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:action, params["action"] || "docs")
      |> assign_component_info(params["component"])

    {:noreply, socket}
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
            selected_component={{ @component_name }}/>
          <div class="container column" style="background-color: #fff; min-height: 500px;">
            <div :if={{ !@component_module }} class="columns is-centered is-vcentered is-mobile" style="height: 300px">
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
                <If condition={{ connected?(@socket) }}>
                  <For each={{ {{example, title, height, code, direction, demo_perc, code_perc}, index} <- Enum.with_index(@examples, 1) }}>
                    <h3 :show={{ @action == "example" && title }} id="example-{{index}}" class="example-title title is-4 is-spaced">
                      <a href="#example-{{index}}">#</a> {{ title }}
                    </h3>
                    <div :show={{ @action == "example" }} class="Example {{direction}}">
                      <div class="demo" style="width: {{demo_perc}}%">
                        <iframe
                          scrolling="no"
                          id="example-iframe-{{index}}"
                          src={{ path_to(@socket, ExampleLive, example, __window_id__: @__window_id__) }}
                          style="overflow-y: hidden; width: 100%; height: {{ height }}px;"
                          frameborder="0"
                          phx-hook="IframeBody"
                        />
                      </div>
                      <div class="code" style="width: {{code_perc}}%">
                        <pre class="language-jsx">
                          <code class="content language-jsx" phx-hook="Highlight" id="example-code-{{index}}">
    {{ code }}</code>
                        </pre>
                      </div>
                    </div>
                  </For>
                  <div :show={{ @action == "playground" }}>
                  <iframe
                    id="playground-iframe"
                    :if={{ @has_playground? }}
                    src={{ path_to(@socket, PlaygroundLive, Enum.at(@playgrounds, 0), __window_id__: @__window_id__) }}
                    style="height: {{ @playground_height }}; width: {{ @playground_width }};"
                    frameborder="0"
                    phx-hook="IframeBody"
                  />
                  </div>
                  <div :show={{ @action == "playground" }} style="padding-top: 1.5rem;">
                    <PlaygroundTools id="playground_tools" session={{ %{"__window_id__" => @__window_id__} }} />
                  </div>
                </If>
                <div :if={{ !connected?(@socket) }} class="container">
                  <div class="columns is-centered is-vcentered is-mobile" style="height: 300px">
                    <div class="column is-narrow has-text-centered subtitle has-text-grey">
                      Loading live {{ @action }}...
                    </div>
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
        height = Keyword.get(playground_config, :height)
        padding = 30
        height && "#{height + padding}px"
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
end
