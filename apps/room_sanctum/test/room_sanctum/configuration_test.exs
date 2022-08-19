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

  describe "visions" do
    alias RoomSanctum.Configuration.Vision

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{name: nil, queries: nil}

    test "list_visions/0 returns all visions" do
      vision = vision_fixture()
      assert Configuration.list_visions() == [vision]
    end

    test "get_vision!/1 returns the vision with given id" do
      vision = vision_fixture()
      assert Configuration.get_vision!(vision.id) == vision
    end

    test "create_vision/1 with valid data creates a vision" do
      valid_attrs = %{name: "some name", queries: %{}}

      assert {:ok, %Vision{} = vision} = Configuration.create_vision(valid_attrs)
      assert vision.name == "some name"
      assert vision.queries == %{}
    end

    test "create_vision/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_vision(@invalid_attrs)
    end

    test "update_vision/2 with valid data updates the vision" do
      vision = vision_fixture()
      update_attrs = %{name: "some updated name", queries: %{}}

      assert {:ok, %Vision{} = vision} = Configuration.update_vision(vision, update_attrs)
      assert vision.name == "some updated name"
      assert vision.queries == %{}
    end

    test "update_vision/2 with invalid data returns error changeset" do
      vision = vision_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_vision(vision, @invalid_attrs)
      assert vision == Configuration.get_vision!(vision.id)
    end

    test "delete_vision/1 deletes the vision" do
      vision = vision_fixture()
      assert {:ok, %Vision{}} = Configuration.delete_vision(vision)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_vision!(vision.id) end
    end

    test "change_vision/1 returns a vision changeset" do
      vision = vision_fixture()
      assert %Ecto.Changeset{} = Configuration.change_vision(vision)
    end
  end

  describe "focis" do
    alias RoomSanctum.Configuration.Foci

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{name: nil, place: nil}

    test "list_focis/0 returns all focis" do
      foci = foci_fixture()
      assert Configuration.list_focis() == [foci]
    end

    test "get_foci!/1 returns the foci with given id" do
      foci = foci_fixture()
      assert Configuration.get_foci!(foci.id) == foci
    end

    test "create_foci/1 with valid data creates a foci" do
      valid_attrs = %{name: "some name", place: "some place"}

      assert {:ok, %Foci{} = foci} = Configuration.create_foci(valid_attrs)
      assert foci.name == "some name"
      assert foci.place == "some place"
    end

    test "create_foci/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_foci(@invalid_attrs)
    end

    test "update_foci/2 with valid data updates the foci" do
      foci = foci_fixture()
      update_attrs = %{name: "some updated name", place: "some updated place"}

      assert {:ok, %Foci{} = foci} = Configuration.update_foci(foci, update_attrs)
      assert foci.name == "some updated name"
      assert foci.place == "some updated place"
    end

    test "update_foci/2 with invalid data returns error changeset" do
      foci = foci_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_foci(foci, @invalid_attrs)
      assert foci == Configuration.get_foci!(foci.id)
    end

    test "delete_foci/1 deletes the foci" do
      foci = foci_fixture()
      assert {:ok, %Foci{}} = Configuration.delete_foci(foci)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_foci!(foci.id) end
    end

    test "change_foci/1 returns a foci changeset" do
      foci = foci_fixture()
      assert %Ecto.Changeset{} = Configuration.change_foci(foci)
    end
  end

  describe "cfg_pythiae" do
    alias RoomSanctum.Configuration.Pythiae

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{ankyra: nil, visions: nil}

    test "list_cfg_pythiae/0 returns all cfg_pythiae" do
      pythiae = pythiae_fixture()
      assert Configuration.list_cfg_pythiae() == [pythiae]
    end

    test "get_pythiae!/1 returns the pythiae with given id" do
      pythiae = pythiae_fixture()
      assert Configuration.get_pythiae!(pythiae.id) == pythiae
    end

    test "create_pythiae/1 with valid data creates a pythiae" do
      valid_attrs = %{ankyra: [], visions: []}

      assert {:ok, %Pythiae{} = pythiae} = Configuration.create_pythiae(valid_attrs)
      assert pythiae.ankyra == []
      assert pythiae.visions == []
    end

    test "create_pythiae/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_pythiae(@invalid_attrs)
    end

    test "update_pythiae/2 with valid data updates the pythiae" do
      pythiae = pythiae_fixture()
      update_attrs = %{ankyra: [], visions: []}

      assert {:ok, %Pythiae{} = pythiae} = Configuration.update_pythiae(pythiae, update_attrs)
      assert pythiae.ankyra == []
      assert pythiae.visions == []
    end

    test "update_pythiae/2 with invalid data returns error changeset" do
      pythiae = pythiae_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_pythiae(pythiae, @invalid_attrs)
      assert pythiae == Configuration.get_pythiae!(pythiae.id)
    end

    test "delete_pythiae/1 deletes the pythiae" do
      pythiae = pythiae_fixture()
      assert {:ok, %Pythiae{}} = Configuration.delete_pythiae(pythiae)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_pythiae!(pythiae.id) end
    end

    test "change_pythiae/1 returns a pythiae changeset" do
      pythiae = pythiae_fixture()
      assert %Ecto.Changeset{} = Configuration.change_pythiae(pythiae)
    end
  end
end
