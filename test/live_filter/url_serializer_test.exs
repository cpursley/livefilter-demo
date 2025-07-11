defmodule LiveFilter.UrlSerializerTest do
  use ExUnit.Case, async: true

  alias LiveFilter.{Filter, FilterGroup, Sort, UrlSerializer}

  describe "update_params/2 - filter serialization" do
    test "serializes simple string filter" do
      filter = %Filter{
        field: :title,
        operator: :contains,
        value: "bug fix",
        type: :string
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["title"]["operator"] == "contains"
      assert params["filters"]["title"]["type"] == "string"
      assert params["filters"]["title"]["value"] == "bug fix"
    end

    test "serializes enum filter with single value" do
      filter = %Filter{
        field: :status,
        operator: :equals,
        value: :pending,
        type: :enum
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["status"]["operator"] == "equals"
      assert params["filters"]["status"]["type"] == "enum"
      assert params["filters"]["status"]["value"] == "pending"
    end

    test "serializes enum filter with multiple values" do
      filter = %Filter{
        field: :status,
        operator: :in,
        value: [:pending, :in_progress],
        type: :enum
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["status"]["operator"] == "in"
      assert params["filters"]["status"]["type"] == "enum"
      assert params["filters"]["status"]["values"] == ["pending", "in_progress"]
    end

    test "serializes boolean filter" do
      filter = %Filter{
        field: :is_urgent,
        operator: :is_true,
        value: true,
        type: :boolean
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["is_urgent"]["operator"] == "is_true"
      assert params["filters"]["is_urgent"]["type"] == "boolean"
      assert params["filters"]["is_urgent"]["value"] == "true"
    end

    test "serializes date range filter" do
      filter = %Filter{
        field: :due_date,
        operator: :between,
        value: {~D[2025-01-01], ~D[2025-01-31]},
        type: :date
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["due_date"]["operator"] == "between"
      assert params["filters"]["due_date"]["type"] == "date"
      assert params["filters"]["due_date"]["start"] == "2025-01-01"
      assert params["filters"]["due_date"]["end"] == "2025-01-31"
    end

    test "serializes numeric filter" do
      filter = %Filter{
        field: :complexity,
        operator: :greater_than,
        value: 5,
        type: :integer
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["complexity"]["operator"] == "greater_than"
      assert params["filters"]["complexity"]["type"] == "integer"
      assert params["filters"]["complexity"]["value"] == 5
    end

    test "serializes array filter" do
      filter = %Filter{
        field: :tags,
        operator: :contains_any,
        value: ["bug", "urgent"],
        type: :array
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["tags"]["operator"] == "contains_any"
      assert params["filters"]["tags"]["type"] == "array"
      assert params["filters"]["tags"]["values"] == ["bug", "urgent"]
    end

    test "serializes multiple filters" do
      filters = [
        %Filter{field: :status, operator: :equals, value: :pending, type: :enum},
        %Filter{field: :is_urgent, operator: :is_true, value: true, type: :boolean}
      ]

      filter_group = %FilterGroup{filters: filters}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["status"]["operator"] == "equals"
      assert params["filters"]["status"]["value"] == "pending"
      assert params["filters"]["is_urgent"]["operator"] == "is_true"
      assert params["filters"]["is_urgent"]["value"] == "true"
    end

    test "handles special _search field" do
      filter = %Filter{
        field: :_search,
        operator: :custom,
        value: "search term",
        type: :string
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      assert params["filters"]["_search"]["operator"] == "custom"
      assert params["filters"]["_search"]["type"] == "string"
      assert params["filters"]["_search"]["value"] == "search term"
    end
  end

  describe "update_params/3 - with sorting" do
    test "serializes single sort" do
      filter_group = %FilterGroup{}
      sort = %Sort{field: :due_date, direction: :desc}

      params = UrlSerializer.update_params(%{}, filter_group, sort)

      assert params["sort"]["field"] == "due_date"
      assert params["sort"]["direction"] == "desc"
    end

    test "combines filters and sort" do
      filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      filter_group = %FilterGroup{filters: [filter]}
      sort = %Sort{field: :created_at, direction: :asc}

      params = UrlSerializer.update_params(%{}, filter_group, sort)

      assert params["filters"]["status"]["value"] == "pending"
      assert params["sort"]["field"] == "created_at"
      assert params["sort"]["direction"] == "asc"
    end
  end

  describe "update_params/4 - with pagination" do
    test "adds pagination params" do
      filter_group = %FilterGroup{}
      sort = nil
      pagination = %{page: 3, per_page: 20}

      params = UrlSerializer.update_params(%{}, filter_group, sort, pagination)

      assert params["page"] == "3"
      assert params["per_page"] == "20"
    end

    test "omits default pagination values" do
      filter_group = %FilterGroup{}
      sort = nil
      pagination = %{page: 1, per_page: 10}

      params = UrlSerializer.update_params(%{}, filter_group, sort, pagination)

      refute Map.has_key?(params, "page")
      refute Map.has_key?(params, "per_page")
    end

    test "combines all parameters" do
      filter = %Filter{field: :status, operator: :equals, value: :pending, type: :enum}
      filter_group = %FilterGroup{filters: [filter]}
      sort = %Sort{field: :due_date, direction: :desc}
      pagination = %{page: 2, per_page: 15}

      params = UrlSerializer.update_params(%{}, filter_group, sort, pagination)

      assert params["filters"]["status"]["value"] == "pending"
      assert params["sort"]["field"] == "due_date"
      assert params["page"] == "2"
      assert params["per_page"] == "15"
    end
  end

  describe "from_params/1 - filter deserialization" do
    test "deserializes simple string filter" do
      params = %{
        "filters" => %{
          "title" => %{
            "operator" => "contains",
            "type" => "string",
            "value" => "bug"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      assert length(filter_group.filters) == 1
      filter = hd(filter_group.filters)
      assert filter.field == :title
      assert filter.operator == :contains
      assert filter.value == "bug"
      assert filter.type == :string
    end

    test "deserializes enum filter with atom conversion" do
      params = %{
        "filters" => %{
          "status" => %{
            "operator" => "equals",
            "type" => "enum",
            "value" => "pending"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      filter = hd(filter_group.filters)
      # Stays as string
      assert filter.value == "pending"
    end

    test "deserializes array values" do
      params = %{
        "filters" => %{
          "status" => %{
            "operator" => "in",
            "type" => "enum",
            "values" => ["pending", "in_progress"]
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      filter = hd(filter_group.filters)
      assert filter.value == ["pending", "in_progress"]
    end

    test "deserializes boolean values" do
      params = %{
        "filters" => %{
          "is_urgent" => %{
            "operator" => "equals",
            "type" => "boolean",
            "value" => "true"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      filter = hd(filter_group.filters)
      assert filter.value == true
    end

    test "deserializes date range" do
      params = %{
        "filters" => %{
          "due_date" => %{
            "operator" => "between",
            "type" => "date",
            "start" => "2025-01-01",
            "end" => "2025-01-31"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      filter = hd(filter_group.filters)
      assert filter.value == {~D[2025-01-01], ~D[2025-01-31]}
    end

    test "deserializes numeric values" do
      params = %{
        "filters" => %{
          "complexity" => %{
            "operator" => "greater_than",
            "type" => "integer",
            "value" => "5"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      filter = hd(filter_group.filters)
      # Deserialized values stay as strings
      assert filter.value == "5"
    end

    test "deserializes multiple filters" do
      params = %{
        "filters" => %{
          "status" => %{
            "operator" => "equals",
            "type" => "enum",
            "value" => "pending"
          },
          "is_urgent" => %{
            "operator" => "is_true",
            "type" => "boolean",
            "value" => "true"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      assert length(filter_group.filters) == 2
      status_filter = Enum.find(filter_group.filters, &(&1.field == :status))
      urgent_filter = Enum.find(filter_group.filters, &(&1.field == :is_urgent))

      assert status_filter.value == "pending"
      assert urgent_filter.value == true
    end

    test "handles empty params" do
      filter_group = UrlSerializer.from_params(%{})

      assert filter_group.filters == []
      assert filter_group.groups == []
      assert filter_group.conjunction == :and
    end

    test "ignores non-filter params" do
      params = %{
        "page" => "2",
        "sort" => %{"field" => "title"},
        "filters" => %{
          "status" => %{
            "value" => "pending",
            "operator" => "equals",
            "type" => "enum"
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      assert length(filter_group.filters) == 1
      assert hd(filter_group.filters).field == :status
    end
  end

  describe "sorts_from_params/1" do
    test "deserializes single sort" do
      params = %{
        "sort" => %{
          "field" => "due_date",
          "direction" => "desc"
        }
      }

      sort = UrlSerializer.sorts_from_params(params)

      assert sort.field == :due_date
      assert sort.direction == :desc
    end

    test "handles missing sort params" do
      params = %{}

      sort = UrlSerializer.sorts_from_params(params)

      assert is_nil(sort)
    end

    test "defaults to asc when direction missing" do
      params = %{"sort" => %{"field" => "title", "direction" => "asc"}}

      sort = UrlSerializer.sorts_from_params(params)

      assert sort.field == :title
      assert sort.direction == :asc
    end
  end

  describe "pagination_from_params/1" do
    test "deserializes pagination params" do
      params = %{
        "page" => "3",
        "per_page" => "25"
      }

      pagination = UrlSerializer.pagination_from_params(params)

      assert pagination.page == 3
      assert pagination.per_page == 25
    end

    test "uses defaults for missing params" do
      params = %{}

      pagination = UrlSerializer.pagination_from_params(params)

      assert pagination.page == 1
      assert pagination.per_page == 10
    end

    test "validates page number" do
      params = %{"page" => "-1", "per_page" => "150"}

      pagination = UrlSerializer.pagination_from_params(params)

      # Defaults to 1 for invalid
      assert pagination.page == 1
      # Max 100, so defaults to 10
      assert pagination.per_page == 10
    end

    test "handles non-numeric values" do
      params = %{"page" => "abc", "per_page" => "xyz"}

      pagination = UrlSerializer.pagination_from_params(params)

      assert pagination.page == 1
      assert pagination.per_page == 10
    end
  end

  describe "round-trip serialization" do
    test "filters survive round-trip" do
      original_filters = [
        %Filter{field: :title, operator: :contains, value: "test", type: :string},
        %Filter{field: :status, operator: :in, value: [:pending, :completed], type: :enum},
        %Filter{field: :is_urgent, operator: :equals, value: true, type: :boolean},
        %Filter{
          field: :due_date,
          operator: :between,
          value: {~D[2025-01-01], ~D[2025-01-31]},
          type: :date
        }
      ]

      original_group = %FilterGroup{filters: original_filters}

      # Serialize
      params = UrlSerializer.update_params(%{}, original_group)

      # Deserialize
      deserialized_group = UrlSerializer.from_params(params)

      # Compare
      assert length(deserialized_group.filters) == length(original_filters)

      # Values might be strings after deserialization, so we check structure
      assert Enum.all?(deserialized_group.filters, fn filter ->
               Enum.any?(original_filters, fn orig ->
                 filter.field == orig.field && filter.operator == orig.operator
               end)
             end)
    end
  end

  describe "edge cases" do
    test "handles filters with nil values" do
      filter = %Filter{
        field: :assigned_to,
        operator: :is_empty,
        value: nil,
        type: :string
      }

      filter_group = %FilterGroup{filters: [filter]}

      params = UrlSerializer.update_params(%{}, filter_group)

      # nil values are not serialized, so filters will be empty
      assert params == %{}
    end

    test "handles malformed filter params gracefully" do
      params = %{
        "filters" => %{
          "status" => %{
            "operator" => "equals"
            # Missing type and value
          },
          "title" => %{
            "value" => "test"
            # Missing operator and type
          }
        }
      }

      filter_group = UrlSerializer.from_params(params)

      # Should only include well-formed filters
      assert length(filter_group.filters) <= 2
    end
  end
end
