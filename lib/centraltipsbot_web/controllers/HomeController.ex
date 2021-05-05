defmodule CentraltipsbotWeb.HomeController do
  use CentraltipsbotWeb, :controller

  def index(conn, _params) do
    conn |> redirect(external: "https://central.tips")
  end
end
