defmodule RoomSanctum.ConfigurationTest do
  use RoomSanctum.DataCase

  alias RoomSanctum.Configuration

  describe "cfg_sources" do
    alias RoomSanctum.Configuration.Source

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{config: nil, enabled: nil, name: nil, notes: nil, type: nil}

    test "list_cfg_sources/0 returns all cfg_sources" do
      source = source_fixture()
      assert Configuration.list_cfg_sources() == [source]
    end

    test "get_source!/1 returns the source with given id" do
      source = source_fixture()
      assert Configuration.get_source!(source.id) == source
    end

    test "create_source/1 with valid data creates a source" do
      valid_attrs = %{config: %{}, enabled: true, name: "some name", notes: "some notes", type: :aqi}

      assert {:ok, %Source{} = source} = Configuration.create_source(valid_attrs)
      assert source.config == %{}
      assert source.enabled == true
      assert source.name == "some name"
      assert source.notes == "some notes"
      assert source.type == :aqi
    end

    test "create_source/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_source(@invalid_attrs)
    end

    test "update_source/2 with valid data updates the source" do
      source = source_fixture()
      update_attrs = %{config: %{}, enabled: false, name: "some updated name", notes: "some updated notes", type: :calendar}

      assert {:ok, %Source{} = source} = Configuration.update_source(source, update_attrs)
      assert source.config == %{}
      assert source.enabled == false
      assert source.name == "some updated name"
      assert source.notes == "some updated notes"
      assert source.type == :calendar
    end

    test "update_source/2 with invalid data returns error changeset" do
      source = source_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_source(source, @invalid_attrs)
      assert source == Configuration.get_source!(source.id)
    end

    test "delete_source/1 deletes the source" do
      source = source_fixture()
      assert {:ok, %Source{}} = Configuration.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_source!(source.id) end
    end

    test "change_source/1 returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = Configuration.change_source(source)
    end
  end

  describe "cfg_queries" do
    alias RoomSanctum.Configuration.Query

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{name: nil, notes: nil, query: nil}

    test "list_cfg_queries/0 returns all cfg_queries" do
      query = query_fixture()
      assert Configuration.list_cfg_queries() == [query]
    end

    test "get_query!/1 returns the query with given id" do
      query = query_fixture()
      assert Configuration.get_query!(query.id) == query
    end

    test "create_query/1 with valid data creates a query" do
      valid_attrs = %{name: "some name", notes: "some notes", query: %{}}

      assert {:ok, %Query{} = query} = Configuration.create_query(valid_attrs)
      assert query.name == "some name"
      assert query.notes == "some notes"
      assert query.query == %{}
    end

    test "create_query/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_query(@invalid_attrs)
    end

    test "update_query/2 with valid data updates the query" do
      query = query_fixture()
      update_attrs = %{name: "some updated name", notes: "some updated notes", query: %{}}

      assert {:ok, %Query{} = query} = Configuration.update_query(query, update_attrs)
      assert query.name == "some updated name"
      assert query.notes == "some updated notes"
      assert query.query == %{}
    end

    test "update_query/2 with invalid data returns error changeset" do
      query = query_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_query(query, @invalid_attrs)
      assert query == Configuration.get_query!(query.id)
    end

    test "delete_query/1 deletes the query" do
      query = query_fixture()
      assert {:ok, %Query{}} = Configuration.delete_query(query)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_query!(query.id) end
    end

    test "change_query/1 returns a query changeset" do
      query = query_fixture()
      assert %Ecto.Changeset{} = Configuration.change_query(query)
    end
  end
end
