defmodule LiveFilter.QuickFiltersTest do
  use ExUnit.Case, async: true

  alias LiveFilter.QuickFilters

  describe "search_filter/2" do
    test "creates basic search filter" do
      filter = QuickFilters.search_filter("test query")

      assert filter.field == :_search
      assert filter.operator == :custom
      assert filter.value == "test query"
      assert filter.type == :string
    end

    test "trims whitespace by default" do
      filter = QuickFilters.search_filter("  test  ")
      assert filter.value == "test"
    end

    test "respects trim option when false" do
      filter = QuickFilters.search_filter("  test  ", trim: false)
      assert filter.value == "  test  "
    end

    test "returns nil for empty string" do
      assert is_nil(QuickFilters.search_filter(""))
      assert is_nil(QuickFilters.search_filter("   "))
    end

    test "respects minimum length" do
      assert is_nil(QuickFilters.search_filter("ab", min_length: 3))
      assert QuickFilters.search_filter("abc", min_length: 3)
    end

    test "uses custom field and operator" do
      filter =
        QuickFilters.search_filter("john",
          field: :author_name,
          operator: :contains
        )

      assert filter.field == :author_name
      assert filter.operator == :contains
    end
  end

  describe "multi_select_filter/3" do
    test "creates filter for multiple values" do
      filter = QuickFilters.multi_select_filter(:status, [:active, :pending])

      assert filter.field == :status
      assert filter.operator == :in
      assert filter.value == [:active, :pending]
      assert filter.type == :enum
    end

    test "creates filter for single value" do
      filter = QuickFilters.multi_select_filter(:status, :active)

      assert filter.operator == :equals
      assert filter.value == :active
    end

    test "returns nil for empty list by default" do
      assert is_nil(QuickFilters.multi_select_filter(:status, []))
    end

    test "returns filter for empty list when reject_empty is false" do
      filter = QuickFilters.multi_select_filter(:status, [], reject_empty: false)
      assert filter.value == []
    end

    test "returns nil for nil value" do
      assert is_nil(QuickFilters.multi_select_filter(:status, nil))
    end

    test "uses custom operator" do
      filter =
        QuickFilters.multi_select_filter(:tags, ["urgent", "bug"],
          operator: :contains_all,
          type: :array
        )

      assert filter.operator == :contains_all
      assert filter.type == :array
    end
  end

  describe "date_range_filter/3" do
    test "creates filter for date range" do
      range = {~D[2025-01-01], ~D[2025-01-31]}
      filter = QuickFilters.date_range_filter(:created_at, range)

      assert filter.field == :created_at
      assert filter.operator == :between
      assert filter.value == range
      assert filter.type == :date
    end

    test "creates filter for single date" do
      date = ~D[2025-01-15]
      filter = QuickFilters.date_range_filter(:due_date, date)

      assert filter.operator == :equals
      assert filter.value == date
    end

    test "returns nil for nil input" do
      assert is_nil(QuickFilters.date_range_filter(:date, nil))
    end

    test "returns nil for incomplete range" do
      assert is_nil(QuickFilters.date_range_filter(:date, {nil, ~D[2025-01-31]}))
      assert is_nil(QuickFilters.date_range_filter(:date, {~D[2025-01-01], nil}))
    end

    test "uses custom operator" do
      filter = QuickFilters.date_range_filter(:created_at, ~D[2025-01-01], operator: :after)

      assert filter.operator == :after
    end

    test "handles preset strings when DateUtils is available" do
      # DateUtils is available, so this should work
      result = QuickFilters.date_range_filter(:date, "last_30_days")

      if Code.ensure_loaded?(LiveFilter.DateUtils) do
        refute is_nil(result)
      else
        assert is_nil(result)
      end
    end
  end

  describe "boolean_filter/3" do
    test "creates filter for true value" do
      filter = QuickFilters.boolean_filter(:is_active, true)

      assert filter.field == :is_active
      assert filter.operator == :equals
      assert filter.value == true
      assert filter.type == :boolean
    end

    test "creates filter for false value" do
      filter = QuickFilters.boolean_filter(:is_active, false)
      assert filter.value == false
    end

    test "returns nil for non-boolean value" do
      assert is_nil(QuickFilters.boolean_filter(:field, "true"))
      assert is_nil(QuickFilters.boolean_filter(:field, 1))
    end

    test "true_only option filters out false values" do
      assert QuickFilters.boolean_filter(:urgent, true, true_only: true)
      assert is_nil(QuickFilters.boolean_filter(:urgent, false, true_only: true))
    end

    test "uses custom operator" do
      filter = QuickFilters.boolean_filter(:flag, true, operator: :is_true)
      assert filter.operator == :is_true
    end
  end

  describe "numeric_filter/3" do
    test "creates filter for integer" do
      filter = QuickFilters.numeric_filter(:age, 25)

      assert filter.field == :age
      assert filter.operator == :equals
      assert filter.value == 25
      assert filter.type == :integer
    end

    test "creates filter for float" do
      filter = QuickFilters.numeric_filter(:price, 99.99)

      assert filter.value == 99.99
      assert filter.type == :float
    end

    test "creates filter for range" do
      filter = QuickFilters.numeric_filter(:score, {80, 100}, operator: :between)

      assert filter.operator == :between
      assert filter.value == {80, 100}
      assert filter.type == :integer
    end

    test "detects float in range" do
      filter = QuickFilters.numeric_filter(:price, {10.5, 99.99}, operator: :between)
      assert filter.type == :float
    end

    test "returns nil for non-numeric value" do
      assert is_nil(QuickFilters.numeric_filter(:field, "not a number"))
    end

    test "uses custom operator" do
      filter = QuickFilters.numeric_filter(:age, 21, operator: :greater_than_or_equal)
      assert filter.operator == :greater_than_or_equal
    end

    test "overrides detected type when specified" do
      filter = QuickFilters.numeric_filter(:value, 42, type: :float)
      assert filter.type == :float
      assert filter.value == 42
    end
  end

  describe "array_filter/3" do
    test "creates array filter" do
      filter = QuickFilters.array_filter(:tags, ["urgent", "bug"])

      assert filter.field == :tags
      assert filter.operator == :contains_any
      assert filter.value == ["urgent", "bug"]
      assert filter.type == :array
    end

    test "returns nil for empty array" do
      assert is_nil(QuickFilters.array_filter(:tags, []))
    end

    test "uses custom operator" do
      filter = QuickFilters.array_filter(:tags, ["a", "b"], operator: :contains_all)
      assert filter.operator == :contains_all
    end

    test "uses custom type" do
      filter = QuickFilters.array_filter(:categories, ["a"], type: :multi_select)
      assert filter.type == :multi_select
    end
  end

  describe "from_params/2" do
    test "builds multiple filters from params" do
      params = %{
        "q" => "search term",
        "status" => ["active", "pending"],
        "urgent" => "true",
        "min_price" => "10.50"
      }

      definitions = [
        {"q", &QuickFilters.search_filter/1},
        {"status", fn v -> QuickFilters.multi_select_filter(:status, v) end},
        {"urgent",
         fn
           "true" -> QuickFilters.boolean_filter(:urgent, true)
           _ -> nil
         end},
        {"min_price",
         fn v ->
           case Float.parse(v) do
             {price, _} ->
               QuickFilters.numeric_filter(:price, price, operator: :greater_than_or_equal)

             _ ->
               nil
           end
         end}
      ]

      filters = QuickFilters.from_params(params, definitions: definitions)

      assert length(filters) == 4
      assert Enum.find(filters, &(&1.field == :_search))
      assert Enum.find(filters, &(&1.field == :status))
      assert Enum.find(filters, &(&1.field == :urgent))

      price_filter = Enum.find(filters, &(&1.field == :price))
      assert price_filter.value == 10.5
      assert price_filter.operator == :greater_than_or_equal
    end

    test "skips nil results from builders" do
      params = %{
        "q" => "",
        "active" => "false"
      }

      definitions = [
        {"q", &QuickFilters.search_filter/1},
        {"active", fn _ -> nil end}
      ]

      filters = QuickFilters.from_params(params, definitions: definitions)
      assert filters == []
    end

    test "handles prefix option" do
      params = %{
        "filter_status" => "active",
        "filter_urgent" => "true"
      }

      definitions = [
        {"status", fn v -> QuickFilters.multi_select_filter(:status, v) end},
        {"urgent",
         fn
           "true" -> QuickFilters.boolean_filter(:urgent, true)
           _ -> nil
         end}
      ]

      filters =
        QuickFilters.from_params(params,
          definitions: definitions,
          prefix: "filter_"
        )

      assert length(filters) == 2
    end
  end

  # Example handlers are documented but not unit tested here
  # since they require proper LiveView socket setup
end
