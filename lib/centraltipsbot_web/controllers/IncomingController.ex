defmodule CentraltipsbotWeb.IncomingController do
  use CentraltipsbotWeb, :controller
  import Plug.Conn

  def check(conn, _params) do
    Centraltipsbot.WalletWatcher.check()
    conn |> send_resp(204, "")
  end
end
