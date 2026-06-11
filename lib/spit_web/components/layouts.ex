defmodule SpitWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SpitWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-30 border-b border-white/8 bg-zinc-950/82 backdrop-blur-xl">
      <div class="mx-auto flex h-14 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <a href={~p"/"} class="group flex w-fit items-center gap-3" aria-label="Spit home">
          <span class="grid size-7 place-items-center rounded-lg border border-orange-400/30 bg-orange-400/10 font-mono text-xs font-bold text-orange-300 shadow-[0_0_30px_rgba(251,146,60,0.12)] transition group-hover:border-orange-300/60 group-hover:bg-orange-400/15">
            &gt;
          </span>
          <span class="font-mono text-[0.82rem] font-semibold tracking-tight text-zinc-100">
            spit
          </span>
        </a>
      </div>
    </header>

    <main class="app-surface min-h-[calc(100vh-3.5rem)] px-4 py-5 sm:px-6 sm:py-7 lg:px-8">
      <div class="mx-auto max-w-7xl space-y-5">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
