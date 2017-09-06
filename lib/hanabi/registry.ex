defmodule Hanabi.Registry do
  use GenServer

  # Used to create the 'users' and 'channels' tables.

  @moduledoc false

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def init(name) do
    table = :ets.new(name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, table}
  end

  ###

  def handle_call({:set, key, value}, _from, table) do
    reply = :ets.insert_new(table, {key, value})

    {:reply, reply, table}
  end

  def handle_call({:update, key, value}, _from, table) do
    reply = :ets.insert(table, {key, value})

    {:reply, reply, table}
  end

  def handle_call({:get, key}, _from, table) do
    lookup = :ets.lookup(table, key)

    reply = case lookup do
      [{_key, value}] -> value
      [] -> nil
    end

    {:reply, reply, table}
  end

  def handle_call({:drop, key}, _from, table) do
    reply = :ets.delete(table, key)

    {:reply, reply, table}
  end

  def handle_call(:dump, _from, table) do
    reply = :ets.match(table, :"$1")
    {:reply, reply, table}
  end

  def handle_call({:flush, table}, _from, table) do
    reply = :ets.delete(table)
    {:ok, new_table} = init(table)
    {:reply, reply, new_table}
  end

  ###

  def set(name, key, value) do
    GenServer.call name, {:set, key, value}
  end

  def update(name, key, value) do
    GenServer.call name, {:update, key, value}
  end

  def get(name, key) do
    GenServer.call name, {:get, key}
  end

  def drop(name, key) do
    GenServer.call name, {:drop, key}
  end

  def dump(name) do
    GenServer.call name, :dump
  end

  def flush(name) do
    GenServer.call name, {:flush, name}
  end
end
