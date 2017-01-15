defmodule SudokuSolver do

    # Define some constants for our playing field
    @rows String.codepoints("ABCDEFGHI")
    @cols String.codepoints("123456789")
    @cells for a <- @rows, b <- @cols, do: a <> b

    @row_units for r <- @rows, do: for c <- @cols, do: r <> c
    @col_units for unit <- List.zip(@row_units), do: Tuple.to_list(unit)
    @box_units for l <- ["ABC", "DEF", "GHI"],
                   n <- ["123", "456", "789"],
                   do: (for alpha <- String.codepoints(l), do: for numeric <- String.codepoints(n), do: alpha <> numeric) |> List.flatten

    @units Map.new(for cell <- @cells do
                                  units = [ Enum.find(@row_units, fn(neighbours) -> Enum.member?(neighbours, cell) end),
                                            Enum.find(@col_units, fn(neighbours) -> Enum.member?(neighbours, cell) end),
                                            Enum.find(@box_units, fn(neighbours) -> Enum.member?(neighbours, cell) end)]

                                  {cell, units}
                              end)
    @peers Map.new(for cell <- @cells do
                       {cell, @units[cell] |> List.flatten |> Enum.uniq |> List.delete(cell)}
                   end)

    def load_file(filename) do
        {:ok, file} = File.read(filename)
        puzzles = file
                    |> String.replace("|", "")
                    |> String.replace("-", "")
                    |> String.replace("0", ".")
                    |> String.replace_trailing("\n", "")
                    |> String.split("\n")

    end

    def parse_grid(puzzle) do
        default_playfield = Map.new(for cell <- @cells, do: {cell, "123456789"})
        puzzle_playfield = grid_values(puzzle)

        # Go through and add all the values from the provided puzzle to a default playfield
        Enum.reduce(puzzle_playfield, {nil, default_playfield}, fn (cell_tuple, puzzle_tuple)->
            cell = elem(cell_tuple, 0)
            value = elem(cell_tuple, 1)
            case Integer.parse(value) do
              # There is surely a better way to do this
              {_, _} -> assign(elem(puzzle_tuple, 1), cell, value)
              :error -> puzzle_tuple
            end
         end)
    end

    @doc """
        Assigns the given value to the given cell, and removes that value from the peers
        of that cell.
    """
    def assign(puzzle, cell, value) do
        other_values = String.replace(puzzle[cell], value, "")
        eliminate(puzzle, cell, other_values)
    end

    def eliminate(puzzle, _cell, "") do
      {:ok, puzzle}
    end

    def eliminate(puzzle, cell, values) do
        {value, remaining} = String.split_at(values, 1)
        case strip_out(puzzle, cell, value) do
          {:ok, puzzle} -> eliminate(puzzle, cell, remaining)
          {:error, message} -> {:error, message}
        end
    end

    defp strip_out(puzzle, cell, value) do
      case eliminate_individual(puzzle, cell, value) do
        {:ok, puzzle} -> check_units(puzzle, cell, value)
        {:error, message} -> {:error, message}
      end
    end

    def eliminate_individual(puzzle, cell, value) do
        if String.contains?(puzzle[cell], value) do
            # Actually gotta check for solution, propogate constraints
            puzzle = Map.put(puzzle, cell, String.replace(puzzle[cell], value, ""))
            cond do
              puzzle[cell] |> String.length == 0 ->
                {:error, "Contradiction: Eliminated all possibilites for cell #{cell}"}
              puzzle[cell] |> String.length == 1 ->
                Enum.reduce_while(@peers[cell],
                            {nil, puzzle},
                            fn(new_cell, puzztup) ->
                              {response, result} = strip_out(elem(puzztup, 1), new_cell, String.first(puzzle[cell]))
                              cond do
                                response == :ok -> {:cont, {response, result}}
                                response == :error -> {:halt, {response, result}}
                              end
                            end
                        )
              true -> {:ok, puzzle}
            end
        else
            # Nothing to remove
            {:ok, puzzle}
        end
    end

    defp check_units(puzzle, cell, value) do

      Enum.reduce_while(@units[cell], {nil, puzzle}, fn(unit, puzztup) ->
        {response, result} = Enum.reduce_while(unit, puzztup, fn(u, puzztup) ->
          my_puzzle = elem(puzztup, 1)
          dplaces = for s <- unit, String.contains?(my_puzzle[s], value), do: s
          cond do
            # If we remove the last option for a cell, bail
            length(dplaces) == 0 -> {:halt, {:error, "Unable to place #{value} after modifying #{cell}"}}
            # If there is only one option for a cell, assign it and update the neighbours
            length(dplaces) == 1 ->
              {response, result} = assign(my_puzzle, List.first(dplaces), value)
              cond do
                response == :ok -> {:cont, {response, result}}
                response == :error -> {:halt, {response, result}}
              end
            # Otherwise there isn't enough information for us to do anything
            true -> {:cont, {:ok, my_puzzle}}
          end
        end
        )

        cond do
          response == :ok -> {:cont, {response, result}}
          response == :error -> {:halt, {response, result}}
        end

        end
      )
    end

    def solve(puzzle) when is_binary(puzzle) do
      {:ok, puzzle_map} = puzzle |> parse_grid
      case search(puzzle_map) do
        {:halt, solution} -> solution # if it's already solved, we'll see this
        solution -> solution          # if it took some work, we'll see this
      end
    end

    defp search(puzzle) do
      if(is_solved(puzzle)) do
        {:halt, puzzle}
      else
        # Find the squares with the fewest available possibilities
        search_options = best_search_options(puzzle)

        # For each of those squares, assign each option and collect the results
        assign_results = for {search_cell, option} <- search_options, do: assign(puzzle, search_cell, option)
        
        # Search the resulting boards
        searchable_puzzles = for {response, result} <- assign_results, response == :ok, do: result

        # Search through the possibilities until we come across a solution
        search_results = Enum.reduce_while(searchable_puzzles, [], fn (searchable_puzzle, acc) -> 
            case search(searchable_puzzle) do
              {:halt, result} -> {:halt, result}  # Found a solution
              result -> {:cont, acc ++ [result]}  # No solutions just yet
            end
          end)
      end
    end

    defp best_search_options(puzzle) do
      search_options = for cell <- @cells, String.length(puzzle[cell]) > 1, do: {cell, puzzle[cell], String.length(puzzle[cell])}
      min_options = Enum.map(search_options, fn({search_cell, options, len}) -> len end) |> Enum.min
      {search_options, _} = Enum.partition(search_options, fn({search_cell, option, len}) -> len == min_options end)
      search_options = (for {search_cell, options, _} <- search_options, do: for option <- String.codepoints(options), do: {search_cell, option}) |> List.flatten

      search_options
    end

    defp is_solved(puzzle) do
      options = Enum.reduce(Map.values(puzzle), 0, fn (cell, count) -> count + String.length(cell) end)
      if (options == 81), do: true, else: false
    end

    @doc """
        Displays a parsed puzzle as a 2D grid of values
    """
    def display(puzzle) when is_map(puzzle) do
        width = 1 + Enum.max(for value <- Map.values(puzzle), do: String.length(value))
        line = [String.duplicate("-", width * 3)]
        lines = line ++ line ++ line
        horizontal_bar = Enum.join(lines, "+") <> "\n"

        delimiters = ["3", "6", "C", "F"]

        rows_text = for row <- @rows do
            cols_text = for col <- @cols do
                cell = row <> col
                cell_text = String.pad_trailing(puzzle[cell], width)
                cell_text <> if col in delimiters, do: "|", else: ""
            end
            Enum.join(cols_text ++ [("\n" <> if row in delimiters, do: horizontal_bar, else: "")])
        end

        Enum.join(rows_text)
    end

    # Create a map along the lines of %{ "A1" => "3", "A2" => ".", "A3" => 8, ...} for an existing puzzle
    def grid_values(puzzle) do
        Map.new(List.zip([@cells, String.codepoints(puzzle)]))
    end

end
