defmodule SudokuSolver do
    

    # Define some constants for our playing field
    @rows String.codepoints("ABCDEFGHI")
    @cols String.codepoints("123456789")
    @cells for a <- @rows, b <- @cols, do: a <> b

    def load_file(filename) do
        {:ok, file} = File.read(filename)
        puzzles = file 
                    |> String.replace("|", "")
                    |> String.replace("-", "")
                    |> String.replace("0", ".")
                    |> String.replace_trailing("\n", "")
                    |> String.split("\n")

    end

    def get_peers() do

        # Get a list of the row elements that are mutual neighbours
        row_unit = cross(@rows, @cols)

        # Get a list of column elements that are mutual neighbours
        col_unit = for unit <- List.zip(row_unit), do: Tuple.to_list(unit)

        # Get the list of box neighbours
        box_unit = for l <- ["ABC", "DEF", "GHI"],
            n <- ["123", "456", "789"],
            do: cross(String.codepoints(l), String.codepoints(n)) |> List.flatten

        # Create a map to relate each cell with a list of its neighbours
        results = for cell <- row_unit |> List.flatten do
            neighbours = [  Enum.find(row_unit, fn(neighbours) -> Enum.member?(neighbours, cell) end),
                            Enum.find(col_unit, fn(neighbours) -> Enum.member?(neighbours, cell) end),
                            Enum.find(box_unit, fn(neighbours) -> Enum.member?(neighbours, cell) end)
                        ]   |> List.flatten
                            |> Enum.uniq
                            |> List.delete(cell)

            {cell, neighbours}
        end

        Map.new(results)
    end

    defp cross(a, b) do
        for aprime <- a do
            for bprime <- b do
                aprime <> bprime
            end
        end
    end

    def parse_grid(puzzle) do
        default_playfield = Map.new(for cell <- @cells, do: {cell, @cols})
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
        other_values = List.delete(puzzle[cell], value)
        eliminate(puzzle, cell, other_values)
    end

    def eliminate(puzzle, _cell, []) do
      {:ok, puzzle}
    end

    def eliminate(puzzle, cell, [ value | remaining ]) do
        case eliminate_individual(puzzle, cell, value) do
          {:ok, puzzle} -> eliminate(puzzle, cell, remaining)
          {:error, message} -> {:error, message}
        end
    end

    def eliminate_individual(puzzle, cell, value) do
        if Enum.member?(puzzle[cell], value) do
            # Actually gotta check for solution, propogate constraints
            puzzle = Map.put(puzzle, cell, List.delete(puzzle[cell], value))
            cond do
              puzzle[cell] |> length == 0 ->
                {:error, "Contradiction: Eliminated all possibilites for cell #{cell}"}
              puzzle[cell] |> length == 1 ->
                Enum.reduce(get_peers[cell],
                            {nil, puzzle},
                            fn(new_cell, puzztup) ->
                                eliminate_individual(elem(puzztup, 1), new_cell, List.first(puzzle[cell]))
                            end
                        )
              true -> {:ok, puzzle}
            end
        else
            # Nothing to remove
            {:ok, puzzle}
        end
    end

    @doc """
        Displays a parsed puzzle as a 2D grid of values
    """
    def display(puzzle) when is_map(puzzle) do
        width = 1 + Enum.max(for value <- Map.values(puzzle), do: length(value))
        line = [String.duplicate("-", width * 3)]
        lines = line ++ line ++ line
        horizontal_bar = Enum.join(lines, "+") <> "\n"

        delimiters = ["3", "6", "C", "F"]

        rows_text = for row <- @rows do
            cols_text = for col <- @cols do
                cell = row <> col
                cell_text = String.pad_leading(Enum.join(puzzle[cell]), width)
                cell_text = String.pad_trailing(Enum.join(puzzle[cell]), width)
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
