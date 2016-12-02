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
end
