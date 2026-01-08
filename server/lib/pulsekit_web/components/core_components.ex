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

  @doc """
  Renders a time range selector component.

  ## Examples

      <.time_range_selector selected={@time_range} on_change="time_range_changed" />
  """
  attr :selected, :string, default: "24h"
  attr :on_change, :string, default: "time_range_changed"
  attr :id, :string, default: "time-range-selector"

  @time_ranges [
    {"1h", "Last hour"},
    {"6h", "Last 6 hours"},
    {"24h", "Last 24 hours"},
    {"7d", "Last 7 days"},
    {"30d", "Last 30 days"}
  ]

  def time_range_selector(assigns) do
    assigns = assign(assigns, :time_ranges, @time_ranges)

    ~H"""
    <div class="flex items-center gap-1 p-1 rounded-lg bg-base-200/50 border border-base-300" id={@id}>
      <%= for {value, label} <- @time_ranges do %>
        <button
          type="button"
          phx-click={@on_change}
          phx-value-range={value}
          class={[
            "px-3 py-1.5 rounded-md text-sm font-medium transition-all duration-150",
            if(@selected == value,
              do: "bg-base-100 text-base-content shadow-sm border border-base-300",
              else: "text-base-content/60 hover:text-base-content hover:bg-base-200"
            )
          ]}
        >
          {label}
        </button>
      <% end %>
    </div>
    """
  end

  @doc """
  Converts a time range string to a DateTime since value.
  """
  def time_range_to_since("1h"), do: DateTime.add(DateTime.utc_now(), -1, :hour)
  def time_range_to_since("6h"), do: DateTime.add(DateTime.utc_now(), -6, :hour)
  def time_range_to_since("24h"), do: DateTime.add(DateTime.utc_now(), -24, :hour)
  def time_range_to_since("7d"), do: DateTime.add(DateTime.utc_now(), -7, :day)
  def time_range_to_since("30d"), do: DateTime.add(DateTime.utc_now(), -30, :day)
  def time_range_to_since(_), do: DateTime.add(DateTime.utc_now(), -24, :hour)

  @doc """
  Renders a sparkline chart using SVG.

  ## Examples

      <.sparkline data={@timeline_data} />
  """
  attr :data, :list, required: true, doc: "List of {datetime, count} tuples"
  attr :width, :integer, default: 200
  attr :height, :integer, default: 40
  attr :color, :string, default: "primary"
  attr :class, :any, default: nil

  def sparkline(assigns) do
    values = Enum.map(assigns.data, fn {_dt, count} -> count end)
    max_value = Enum.max(values ++ [1])
    min_value = 0

    points =
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        x = index / max(length(values) - 1, 1) * assigns.width
        y = assigns.height - (value - min_value) / max(max_value - min_value, 1) * assigns.height
        {x, y}
      end)

    path_data =
      points
      |> Enum.with_index()
      |> Enum.map(fn {{x, y}, index} ->
        if index == 0, do: "M #{x} #{y}", else: "L #{x} #{y}"
      end)
      |> Enum.join(" ")

    # Create fill area path
    fill_path =
      if length(points) > 0 do
        {first_x, _} = List.first(points)
        {last_x, _} = List.last(points)
        path_data <> " L #{last_x} #{assigns.height} L #{first_x} #{assigns.height} Z"
      else
        ""
      end

    stroke_color = case assigns.color do
      "primary" -> "stroke-primary"
      "error" -> "stroke-error"
      "warning" -> "stroke-warning"
      "info" -> "stroke-info"
      "success" -> "stroke-success"
      _ -> "stroke-primary"
    end

    fill_color = case assigns.color do
      "primary" -> "fill-primary/10"
      "error" -> "fill-error/10"
      "warning" -> "fill-warning/10"
      "info" -> "fill-info/10"
      "success" -> "fill-success/10"
      _ -> "fill-primary/10"
    end

    assigns = assign(assigns, :path_data, path_data)
    assigns = assign(assigns, :fill_path, fill_path)
    assigns = assign(assigns, :stroke_color, stroke_color)
    assigns = assign(assigns, :fill_color, fill_color)

    ~H"""
    <svg
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      class={["overflow-visible", @class]}
      preserveAspectRatio="none"
    >
      <%= if @fill_path != "" do %>
        <path d={@fill_path} class={@fill_color} />
        <path d={@path_data} fill="none" class={[@stroke_color, "stroke-[1.5]"]} stroke-linecap="round" stroke-linejoin="round" />
      <% end %>
    </svg>
    """
  end

  @doc """
  Renders an event timeline chart with labels.

  ## Examples

      <.event_timeline data={@timeline_data} time_range={@time_range} />
  """
  attr :data, :list, required: true, doc: "List of {datetime, count} tuples"
  attr :time_range, :string, default: "24h"
  attr :class, :any, default: nil

  def event_timeline(assigns) do
    total_events = assigns.data |> Enum.map(fn {_dt, count} -> count end) |> Enum.sum()

    assigns = assign(assigns, :total_events, total_events)

    ~H"""
    <div class={["rounded-xl border border-base-300 bg-base-100 shadow-sm overflow-hidden", @class]}>
      <div class="flex items-center justify-between px-5 py-4 border-b border-base-200">
        <div>
          <h2 class="text-base font-semibold text-base-content">Event Timeline</h2>
          <p class="text-xs text-base-content/50 mt-0.5">{format_time_range_label(@time_range)}</p>
        </div>
        <div class="text-right">
          <p class="text-2xl font-bold text-base-content">{format_number(@total_events)}</p>
          <p class="text-xs text-base-content/50">total events</p>
        </div>
      </div>
      <div class="p-5">
        <div class="h-24">
          <.sparkline data={@data} width={600} height={96} color="primary" class="w-full h-full" />
        </div>
        <div class="flex justify-between mt-2 text-xs text-base-content/40">
          <span>{format_timeline_start(@time_range)}</span>
          <span>Now</span>
        </div>
      </div>
    </div>
    """
  end

  defp format_time_range_label("1h"), do: "Last hour"
  defp format_time_range_label("6h"), do: "Last 6 hours"
  defp format_time_range_label("24h"), do: "Last 24 hours"
  defp format_time_range_label("7d"), do: "Last 7 days"
  defp format_time_range_label("30d"), do: "Last 30 days"
  defp format_time_range_label(_), do: "Last 24 hours"

  defp format_timeline_start("1h"), do: "1 hour ago"
  defp format_timeline_start("6h"), do: "6 hours ago"
  defp format_timeline_start("24h"), do: "24 hours ago"
  defp format_timeline_start("7d"), do: "7 days ago"
  defp format_timeline_start("30d"), do: "30 days ago"
  defp format_timeline_start(_), do: "24 hours ago"

  defp format_number(num) when num >= 1_000_000, do: "#{Float.round(num / 1_000_000, 1)}M"
  defp format_number(num) when num >= 1_000, do: "#{Float.round(num / 1_000, 1)}K"
  defp format_number(num), do: "#{num}"

  @doc """
  Renders a command palette component for global search.

  ## Examples

      <.command_palette id="cmd-palette" />
  """
  attr :id, :string, default: "command-palette"

  def command_palette(assigns) do
    ~H"""
    <div
      id={@id}
      class="hidden fixed inset-0 z-[100]"
    >
      <%!-- Backdrop --%>
      <div
        class="absolute inset-0 bg-black/50 backdrop-blur-sm"
        phx-click={hide_command_palette(@id)}
      />

      <%!-- Modal --%>
      <div class="absolute top-[20%] left-1/2 -translate-x-1/2 w-full max-w-xl mx-4">
        <div class="rounded-xl border border-base-300 bg-base-100 shadow-2xl overflow-hidden">
          <%!-- Search Input --%>
          <div class="flex items-center gap-3 px-4 py-3 border-b border-base-200">
            <.icon name="hero-magnifying-glass" class="w-5 h-5 text-base-content/40 flex-shrink-0" />
            <input
              type="text"
              id={@id <> "-input"}
              placeholder="Search events, issues, projects..."
              class="flex-1 bg-transparent border-none outline-none text-base-content placeholder:text-base-content/40 text-sm"
              phx-keydown={hide_command_palette(@id)}
              phx-key="Escape"
              autocomplete="off"
            />
            <kbd class="hidden sm:inline-flex items-center gap-1 px-2 py-1 rounded bg-base-200 text-xs font-medium text-base-content/50">
              ESC
            </kbd>
          </div>

          <%!-- Quick Links --%>
          <div class="p-2">
            <p class="px-3 py-2 text-xs font-semibold uppercase tracking-wider text-base-content/40">Quick Navigation</p>
            <nav class="space-y-0.5">
              <.command_link href="/" icon="hero-chart-bar" label="Dashboard" shortcut="G D" />
              <.command_link href="/issues" icon="hero-bug-ant" label="Issues" shortcut="G I" />
              <.command_link href="/events" icon="hero-exclamation-triangle" label="Events" shortcut="G E" />
              <.command_link href="/projects" icon="hero-folder" label="Projects" shortcut="G P" />
              <.command_link href="/alerts" icon="hero-bell" label="Alerts" shortcut="G A" />
              <.command_link href="/settings" icon="hero-cog-6-tooth" label="Settings" shortcut="G S" />
            </nav>
          </div>

          <%!-- Actions --%>
          <div class="p-2 border-t border-base-200">
            <p class="px-3 py-2 text-xs font-semibold uppercase tracking-wider text-base-content/40">Actions</p>
            <nav class="space-y-0.5">
              <.command_link href="/projects/new" icon="hero-plus" label="Create New Project" />
              <.command_link href="/alerts/new" icon="hero-bell-alert" label="Create New Alert" />
            </nav>
          </div>

          <%!-- Footer --%>
          <div class="flex items-center justify-between px-4 py-2 border-t border-base-200 bg-base-200/30">
            <div class="flex items-center gap-4 text-xs text-base-content/50">
              <span class="flex items-center gap-1">
                <kbd class="px-1.5 py-0.5 rounded bg-base-200 font-medium">↑↓</kbd>
                navigate
              </span>
              <span class="flex items-center gap-1">
                <kbd class="px-1.5 py-0.5 rounded bg-base-200 font-medium">↵</kbd>
                select
              </span>
            </div>
            <span class="text-xs text-base-content/40">PulseKit</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :shortcut, :string, default: nil

  defp command_link(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-base-content hover:bg-base-200 transition-colors duration-100"
    >
      <.icon name={@icon} class="w-4 h-4 text-base-content/50" />
      <span class="flex-1">{@label}</span>
      <kbd :if={@shortcut} class="hidden sm:inline-flex px-1.5 py-0.5 rounded bg-base-200 text-xs font-medium text-base-content/50">
        {@shortcut}
      </kbd>
    </a>
    """
  end

  defp hide_command_palette(id) do
    JS.add_class("hidden", to: "##{id}")
  end
end
