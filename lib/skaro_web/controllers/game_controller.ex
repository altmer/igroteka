defmodule SkaroWeb.GameController do
  use SkaroWeb, :controller

  alias Skaro.Backlog.Entries
  alias Skaro.Core
  alias Skaro.Guardian.Plug, as: GuardianPlug

  action_fallback(SkaroWeb.FallbackController)

  plug(Guardian.Plug.EnsureAuthenticated)

  @spec index(any, map) :: {:error, :external_api, any} | Plug.Conn.t()
  def index(conn, %{"term" => term}) do
    term
    |> Core.search(current_user_id(conn))
    |> respond(conn)
  end

  def index(conn, %{"new" => _}) do
    conn
    |> current_user_id()
    |> Core.new_games()
    |> respond(conn)
  end

  def index(conn, %{"developer" => _} = params) do
    params
    |> Core.fetch_games(current_user_id(conn))
    |> respond(conn)
  end

  def index(conn, %{"publisher" => _} = params) do
    params
    |> Core.fetch_games(current_user_id(conn))
    |> respond(conn)
  end

  def index(conn, params) do
    params
    |> Core.top_games(current_user_id(conn))
    |> respond(conn)
  end

  @spec show(any, map) :: {:error, :external_api, any} | Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    id
    |> Core.get()
    |> schedule_backlog_updates()
    |> respond(conn)
  end

  defp schedule_backlog_updates({:ok, game}) do
    # trace this async operation
    Task.async(fn ->
      Tracer.with_span "game.update_entries_for_game.async",
        kind: :client,
        attributes: %{game_id: game.id} do
        Entries.update_entries_for_game(game)
      end
    end)

    {:ok, game}
  end

  defp schedule_backlog_updates({:error, _} = error_tuple) do
    error_tuple
  end

  defp respond({:ok, games}, conn) when is_list(games) do
    Tracer.set_attribute(:result, :ok)
    Tracer.set_status(OpenTelemetry.status(:ok, ""))

    render(conn, "index.json", games: games)
  end

  defp respond({:ok, game}, conn) do
    Tracer.set_attribute(:result, :ok)
    Tracer.set_status(OpenTelemetry.status(:ok, ""))

    render(conn, "show.json", game: game)
  end

  defp respond({:error, reason}, _) do
    Tracer.set_attribute(:result, :external_api_failure)
    Tracer.set_status(OpenTelemetry.status(:error, "IGDB API failure: #{reason}"))

    {:error, :external_api, reason}
  end

  defp current_user_id(conn) do
    GuardianPlug.current_resource(conn).id
  end
end
