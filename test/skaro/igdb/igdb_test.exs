defmodule Skaro.IGDBTest do
  @moduledoc false
  use Skaro.DataCase

  alias Plug.Conn

  alias Skaro.Core.{ExternalLink, Game, Image, Platform}
  alias Skaro.IGDB

  describe "search/1" do
    @tag :bypass
    test "ok response", %{igdb_api: igdb_api} do
      Bypass.expect_once(
        igdb_api,
        "POST",
        "/search",
        fn conn ->
          assert ["igdb_api_key"] = Conn.get_req_header(conn, "user-key")
          assert {:ok, "search \"warcraft\";" <> _, conn} = Conn.read_body(conn)

          Conn.resp(conn, 200, """
          [
            {
              "game": {
                "aggregated_rating": 92.5,
                "aggregated_rating_count": 1,
                "cover": {
                  "id": 129,
                  "image_id": "olpk2nfqu4susanmykqu"
                },
                "first_release_date": 818467200,
                "id": 130,
                "name": "Warcraft II: Tides of Darkness",
                "platforms": [
                  {"id": 6, "name": "PC (Microsoft Windows)"},
                  {"id": 7, "name": "PlayStation"},
                  {"id": 13, "name": "PC DOS"},
                  {"id": 14, "name": "Mac"},
                  {"id": 32, "name": "Sega Saturn"}
                ],
                "summary": "Warcraft 2 is a successor of the popular Warcraft real-time strategy game. The game contains many improvements over the previous version in graphics, sounds and playability. The game contains many improvements over the previous version in graphics, sounds and playability. The game contains many improvements over the previous version in graphics, sounds and playability."
              },
              "id": 94347
            },
            {
              "game": {
                "aggregated_rating": 93.0,
                "aggregated_rating_count": 4,
                "first_release_date": 1025654400,
                "id": 132,
                "name": "Warcraft III: Reign of Chaos",
                "platforms": [
                  {"id": 6, "name": "PC (Microsoft Windows)"},
                  {"id": 14, "name": "Mac"}
                ],
                "summary": "Warcraft 3: Reign of Chaos is an RTS made by Blizzard Entertainment. Take control of either the Humans, the Orcs, the Night Elves or the Undead, all with different unit types and heroes with unique abilities."
              },
              "id": 99466
            }
          ]
          """)
        end
      )

      expected_games = [
        %Game{
          id: 130,
          external_id: 130,
          name: "Warcraft II: Tides of Darkness",
          short_description:
            "Warcraft 2 is a successor of the popular Warcraft real-time strategy game. The game contains many improvements over the previous version in graphics, sounds and playability. The game contains many improvements over the previous version in graphics, sounds and playability. The game contains many i...",
          release_date: DateTime.from_naive!(~N[1995-12-09 00:00:00], "Etc/UTC"),
          rating: 92.5,
          ratings_count: 1,
          platforms: [
            %Platform{id: 6, external_id: 6, name: "PC (Microsoft Windows)"},
            %Platform{id: 7, external_id: 7, name: "PlayStation"},
            %Platform{id: 13, external_id: 13, name: "PC DOS"},
            %Platform{id: 14, external_id: 14, name: "Mac"},
            %Platform{id: 32, external_id: 32, name: "Sega Saturn"}
          ],
          cover: %Image{
            id: "olpk2nfqu4susanmykqu",
            big_url:
              "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/olpk2nfqu4susanmykqu.jpg",
            thumb_url:
              "https://images.igdb.com/igdb/image/upload/t_cover_small_2x/olpk2nfqu4susanmykqu.jpg"
          }
        },
        %Game{
          id: 132,
          external_id: 132,
          name: "Warcraft III: Reign of Chaos",
          short_description:
            "Warcraft 3: Reign of Chaos is an RTS made by Blizzard Entertainment. Take control of either the Humans, the Orcs, the Night Elves or the Undead, all with different unit types and heroes with unique abilities.",
          release_date: DateTime.from_naive!(~N[2002-07-03 00:00:00], "Etc/UTC"),
          rating: 93.0,
          ratings_count: 4,
          platforms: [
            %Platform{id: 6, external_id: 6, name: "PC (Microsoft Windows)"},
            %Platform{id: 14, external_id: 14, name: "Mac"}
          ],
          cover: %Image{
            id: -1,
            big_url: "https://via.placeholder.com/160x192?text=No%20cover",
            thumb_url: "https://via.placeholder.com/100x120?text=No%20cover"
          }
        }
      ]

      assert {:ok, expected_games} == IGDB.search("warcraft")
    end

    @tag :bypass
    test "no connection", %{igdb_api: igdb_api} do
      Bypass.down(igdb_api)

      assert {:error, :econnrefused} == IGDB.search("term")
    end

    @tag :bypass
    test "internal IGDB error", %{igdb_api: igdb_api} do
      Bypass.expect_once(
        igdb_api,
        "POST",
        "/search",
        fn conn ->
          Conn.resp(conn, 200, """
          [
            {
              "status": "400",
              "title": "Bad request"
            }
          ]
          """)
        end
      )

      assert {:error, "Code 400, reason: Bad request"} == IGDB.search("term")
    end
  end

  describe "find_one/1" do
    @tag :bypass
    test "ok response", %{igdb_api: igdb_api} do
      Bypass.expect_once(
        igdb_api,
        "POST",
        "/games",
        fn conn ->
          conn = Conn.fetch_query_params(conn)

          assert ["igdb_api_key"] = Conn.get_req_header(conn, "user-key")
          assert {:ok, "where id = 132;" <> _, conn} = Conn.read_body(conn)

          Conn.resp(conn, 200, File.read!("./test/support/fixtures/igdb_find_one.json"))
        end
      )

      assert {:ok, game} = IGDB.find_one(132)
      assert game.external_id == 132

      assert [
               %ExternalLink{
                 category: "official",
                 external_category_id: 1,
                 external_id: 13_276,
                 url: "http://us.blizzard.com/en-us/games/war3/"
               },
               %ExternalLink{
                 category: "wikia",
                 external_category_id: 2,
                 external_id: 13_277,
                 url: "http://wowwiki.wikia.com/wiki/Warcraft_III:_Reign_of_Chaos"
               },
               %ExternalLink{
                 category: "wikipedia",
                 external_category_id: 3,
                 external_id: 13_278,
                 url: "https://en.wikipedia.org/wiki/Warcraft_III:_Reign_of_Chaos"
               },
               %ExternalLink{
                 category: "facebook",
                 external_category_id: 4,
                 external_id: 78_789,
                 url: "https://www.facebook.com/WC3Europe"
               },
               %ExternalLink{
                 category: "reddit",
                 external_category_id: 14,
                 external_id: 78_790,
                 url: "https://www.reddit.com/r/WC3"
               }
             ] = game.external_links
    end

    @tag :bypass
    test "not found", %{igdb_api: igdb_api} do
      Bypass.expect_once(
        igdb_api,
        "POST",
        "/games",
        fn conn ->
          Conn.resp(conn, 200, "[]")
        end
      )

      assert {:error, :not_found} == IGDB.find_one(-1)
    end
  end
end
