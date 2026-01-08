defmodule PulsekitWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-mounted={JS.transition({"transition-all duration-200 ease-out", "translate-x-full opacity-0", "translate-x-0 opacity-100"})}
      role="alert"
      class="fixed top-4 right-4 z-50"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 w-80 sm:w-96 p-4 rounded-lg shadow-lg border",
        "bg-base-100 backdrop-blur-sm",
        @kind == :info && "border-primary/30",
        @kind == :error && "border-error/30"
      ]}>
        <div class={[
          "flex-shrink-0 p-1.5 rounded-full",
          @kind == :info && "bg-primary/10 text-primary",
          @kind == :error && "bg-error/10 text-error"
        ]}>
          <.icon :if={@kind == :info} name="hero-information-circle" class="size-5" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5" />
        </div>
        <div class="flex-1 min-w-0">
          <p :if={@title} class="font-semibold text-base-content">{@title}</p>
          <p class={[
            "text-sm",
            if(@title, do: "text-base-content/70 mt-0.5", else: "text-base-content")
          ]}>{msg}</p>
        </div>
        <button
          type="button"
          class="flex-shrink-0 p-1 rounded-md text-base-content/50 hover:text-base-content hover:bg-base-200 transition-colors duration-150"
          aria-label="close"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, default: nil, doc: "button variant: primary, secondary, ghost, outline"
  attr :size, :string, values: ~w(sm md lg), default: "md"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    base_classes = "inline-flex items-center justify-center gap-2 font-medium rounded-lg transition-all duration-150 active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed"

    size_classes = %{
      "sm" => "px-3 py-1.5 text-sm",
      "md" => "px-4 py-2 text-sm",
      "lg" => "px-5 py-2.5 text-base"
    }

    variant_classes = %{
      "primary" => "bg-primary text-primary-content hover:brightness-110 shadow-sm hover:shadow-md",
      "secondary" => "bg-base-200 text-base-content hover:bg-base-300",
      "ghost" => "text-base-content/70 hover:text-base-content hover:bg-base-200",
      "outline" => "border border-base-300 text-base-content hover:bg-base-200 hover:border-base-400",
      nil => "bg-primary/10 text-primary hover:bg-primary/20"
    }

    assigns =
      assign_new(assigns, :class, fn ->
        [
          base_classes,
          Map.fetch!(size_classes, assigns.size),
          Map.fetch!(variant_classes, assigns[:variant])
        ]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-4">
      <label class="flex items-center gap-3 cursor-pointer group">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <div class="relative">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || [
              "peer sr-only"
            ]}
            {@rest}
          />
          <div class={[
            "w-5 h-5 rounded border-2 transition-all duration-150",
            "border-base-300 bg-base-100",
            "peer-checked:bg-primary peer-checked:border-primary",
            "peer-focus:ring-2 peer-focus:ring-primary/20",
            "group-hover:border-primary/50"
          ]}>
            <.icon name="hero-check" class="w-4 h-4 text-primary-content opacity-0 peer-checked:opacity-100 transition-opacity" />
          </div>
        </div>
        <span class="text-sm font-medium text-base-content select-none">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-4">
      <label :if={@label} class="block text-sm font-medium text-base-content mb-1.5">
        {@label}
      </label>
      <select
        id={@id}
        name={@name}
        class={[
          @class || [
            "w-full px-3 py-2 rounded-lg border bg-base-100 text-base-content",
            "border-base-300 focus:border-primary focus:ring-2 focus:ring-primary/20",
            "transition-all duration-150 outline-none appearance-none cursor-pointer"
          ],
          @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
        ]}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-4">
      <label :if={@label} class="block text-sm font-medium text-base-content mb-1.5">
        {@label}
      </label>
      <textarea
        id={@id}
        name={@name}
        class={[
          @class || [
            "w-full px-3 py-2 rounded-lg border bg-base-100 text-base-content",
            "border-base-300 focus:border-primary focus:ring-2 focus:ring-primary/20",
            "transition-all duration-150 outline-none resize-y min-h-[100px]",
            "placeholder:text-base-content/40"
          ],
          @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-4">
      <label :if={@label} class="block text-sm font-medium text-base-content mb-1.5">
        {@label}
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          @class || [
            "w-full px-3 py-2 rounded-lg border bg-base-100 text-base-content",
            "border-base-300 focus:border-primary focus:ring-2 focus:ring-primary/20",
            "transition-all duration-150 outline-none",
            "placeholder:text-base-content/40"
          ],
          @errors != [] && (@error_class || "border-error focus:border-error focus:ring-error/20")
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-1.5 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-4 flex-shrink-0" />
      <span>{render_slot(@inner_block)}</span>
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "mb-6"]}>
      <div>
        <h1 class="text-2xl font-bold text-base-content tracking-tight">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/60 mt-1">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none flex items-center gap-3">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-hidden rounded-lg border border-base-300 bg-base-100">
      <table class="w-full">
        <thead>
          <tr class="border-b border-base-300 bg-base-200/50">
            <th
              :for={col <- @col}
              class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-base-content/70"
            >
              {col[:label]}
            </th>
            <th :if={@action != []} class="px-4 py-3 text-right">
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"} class="divide-y divide-base-200">
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="hover:bg-base-200/50 transition-colors duration-100">
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-4 py-3 text-sm text-base-content", @row_click && "cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="px-4 py-3 text-right">
              <div class="flex items-center justify-end gap-2">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-base-200">
      <div :for={item <- @item} class="py-3 flex items-center justify-between gap-4">
        <dt class="text-sm font-medium text-base-content/70">{item.title}</dt>
        <dd class="text-sm text-base-content">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc """
  Renders a card component.
  """
  attr :class, :any, default: nil
  attr :elevated, :boolean, default: false
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border border-base-300 bg-base-100",
      if(@elevated, do: "shadow-md hover:shadow-lg transition-shadow duration-150", else: "shadow-sm"),
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a badge component.
  """
  attr :variant, :string, values: ~w(default primary error warning info success), default: "default"
  attr :size, :string, values: ~w(sm md), default: "md"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    variant_classes = %{
      "default" => "bg-base-200 text-base-content border-base-300",
      "primary" => "bg-primary/10 text-primary border-primary/30",
      "error" => "bg-error/10 text-error border-error/30",
      "warning" => "bg-warning/10 text-warning border-warning/30",
      "info" => "bg-info/10 text-info border-info/30",
      "success" => "bg-success/10 text-success border-success/30"
    }

    size_classes = %{
      "sm" => "px-1.5 py-0.5 text-xs",
      "md" => "px-2 py-1 text-xs"
    }

    assigns = assign(assigns, :variant_class, Map.fetch!(variant_classes, assigns.variant))
    assigns = assign(assigns, :size_class, Map.fetch!(size_classes, assigns.size))

    ~H"""
    <span class={[
      "inline-flex items-center font-medium rounded border",
      @variant_class,
      @size_class,
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-out duration-200",
         "opacity-0 translate-y-2 scale-95",
         "opacity-100 translate-y-0 scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition:
        {"transition-all ease-in duration-150", "opacity-100 translate-y-0 scale-100",
         "opacity-0 translate-y-2 scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(PulsekitWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(PulsekitWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
