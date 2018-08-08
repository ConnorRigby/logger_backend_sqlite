defmodule LoggerBackendEctoTest do
  use ExUnit.Case
  doctest LoggerBackendEcto

  test "greets the world" do
    assert LoggerBackendEcto.hello() == :world
  end
end
