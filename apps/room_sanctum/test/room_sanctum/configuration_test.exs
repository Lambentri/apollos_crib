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
      valid_attrs = %{
        config: %{},
        enabled: true,
        name: "some name",
        notes: "some notes",
        type: :aqi
      }

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

      update_attrs = %{
        config: %{},
        enabled: false,
        name: "some updated name",
        notes: "some updated notes",
        type: :calendar
      }

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

  describe "cfg_scribus" do
    alias RoomSanctum.Configuration.Scribus

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{configuration: nil, name: nil, resolution: nil}

    test "list_cfg_scribus/0 returns all cfg_scribus" do
      scribus = scribus_fixture()
      assert Configuration.list_cfg_scribus() == [scribus]
    end

    test "get_scribus!/1 returns the scribus with given id" do
      scribus = scribus_fixture()
      assert Configuration.get_scribus!(scribus.id) == scribus
    end

    test "create_scribus/1 with valid data creates a scribus" do
      valid_attrs = %{configuration: [], name: "some name", resolution: "some resolution"}

      assert {:ok, %Scribus{} = scribus} = Configuration.create_scribus(valid_attrs)
      assert scribus.configuration == []
      assert scribus.name == "some name"
      assert scribus.resolution == "some resolution"
    end

    test "create_scribus/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_scribus(@invalid_attrs)
    end

    test "update_scribus/2 with valid data updates the scribus" do
      scribus = scribus_fixture()

      update_attrs = %{
        configuration: [],
        name: "some updated name",
        resolution: "some updated resolution"
      }

      assert {:ok, %Scribus{} = scribus} = Configuration.update_scribus(scribus, update_attrs)
      assert scribus.configuration == []
      assert scribus.name == "some updated name"
      assert scribus.resolution == "some updated resolution"
    end

    test "update_scribus/2 with invalid data returns error changeset" do
      scribus = scribus_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_scribus(scribus, @invalid_attrs)
      assert scribus == Configuration.get_scribus!(scribus.id)
    end

    test "delete_scribus/1 deletes the scribus" do
      scribus = scribus_fixture()
      assert {:ok, %Scribus{}} = Configuration.delete_scribus(scribus)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_scribus!(scribus.id) end
    end

    test "change_scribus/1 returns a scribus changeset" do
      scribus = scribus_fixture()
      assert %Ecto.Changeset{} = Configuration.change_scribus(scribus)
    end
  end

  describe "cfg_webhooks" do
    alias RoomSanctum.Configuration.Agyr

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{user: nil, path: nil, token: nil, designator: nil}

    test "list_cfg_webhooks/0 returns all cfg_webhooks" do
      agyr = agyr_fixture()
      assert Configuration.list_cfg_webhooks() == [agyr]
    end

    test "get_agyr!/1 returns the agyr with given id" do
      agyr = agyr_fixture()
      assert Configuration.get_agyr!(agyr.id) == agyr
    end

    test "create_agyr/1 with valid data creates a agyr" do
      valid_attrs = %{user: "some user", path: "some path", token: "some token", designator: "some designator"}

      assert {:ok, %Agyr{} = agyr} = Configuration.create_agyr(valid_attrs)
      assert agyr.user == "some user"
      assert agyr.path == "some path"
      assert agyr.token == "some token"
      assert agyr.designator == "some designator"
    end

    test "create_agyr/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_agyr(@invalid_attrs)
    end

    test "update_agyr/2 with valid data updates the agyr" do
      agyr = agyr_fixture()
      update_attrs = %{user: "some updated user", path: "some updated path", token: "some updated token", designator: "some updated designator"}

      assert {:ok, %Agyr{} = agyr} = Configuration.update_agyr(agyr, update_attrs)
      assert agyr.user == "some updated user"
      assert agyr.path == "some updated path"
      assert agyr.token == "some updated token"
      assert agyr.designator == "some updated designator"
    end

    test "update_agyr/2 with invalid data returns error changeset" do
      agyr = agyr_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_agyr(agyr, @invalid_attrs)
      assert agyr == Configuration.get_agyr!(agyr.id)
    end

    test "delete_agyr/1 deletes the agyr" do
      agyr = agyr_fixture()
      assert {:ok, %Agyr{}} = Configuration.delete_agyr(agyr)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_agyr!(agyr.id) end
    end

    test "change_agyr/1 returns a agyr changeset" do
      agyr = agyr_fixture()
      assert %Ecto.Changeset{} = Configuration.change_agyr(agyr)
    end
  end

  describe "cfg_mailboxes" do
    alias RoomSanctum.Configuration.Taxid

    import RoomSanctum.ConfigurationFixtures

    @invalid_attrs %{user: nil, designator: nil}

    test "list_cfg_mailboxes/0 returns all cfg_mailboxes" do
      taxid = taxid_fixture()
      assert Configuration.list_cfg_mailboxes() == [taxid]
    end

    test "get_taxid!/1 returns the taxid with given id" do
      taxid = taxid_fixture()
      assert Configuration.get_taxid!(taxid.id) == taxid
    end

    test "create_taxid/1 with valid data creates a taxid" do
      valid_attrs = %{user: "some user", designator: "some designator"}

      assert {:ok, %Taxid{} = taxid} = Configuration.create_taxid(valid_attrs)
      assert taxid.user == "some user"
      assert taxid.designator == "some designator"
    end

    test "create_taxid/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Configuration.create_taxid(@invalid_attrs)
    end

    test "update_taxid/2 with valid data updates the taxid" do
      taxid = taxid_fixture()
      update_attrs = %{user: "some updated user", designator: "some updated designator"}

      assert {:ok, %Taxid{} = taxid} = Configuration.update_taxid(taxid, update_attrs)
      assert taxid.user == "some updated user"
      assert taxid.designator == "some updated designator"
    end

    test "update_taxid/2 with invalid data returns error changeset" do
      taxid = taxid_fixture()
      assert {:error, %Ecto.Changeset{}} = Configuration.update_taxid(taxid, @invalid_attrs)
      assert taxid == Configuration.get_taxid!(taxid.id)
    end

    test "delete_taxid/1 deletes the taxid" do
      taxid = taxid_fixture()
      assert {:ok, %Taxid{}} = Configuration.delete_taxid(taxid)
      assert_raise Ecto.NoResultsError, fn -> Configuration.get_taxid!(taxid.id) end
    end

    test "change_taxid/1 returns a taxid changeset" do
      taxid = taxid_fixture()
      assert %Ecto.Changeset{} = Configuration.change_taxid(taxid)
    end
  end
end
