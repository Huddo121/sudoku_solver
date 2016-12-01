defmodule SudokuSolver do
    
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
        rows = String.codepoints("ABCDEFGHI")
        cols = String.codepoints("123456789")

        # Get a list of the row elements that are mutual neighbours
        row_unit = cross(rows, cols)

        # Get a list of column elements that are mutual neighbours
        col_unit = for unit <- List.zip(row_unit), do: Tuple.to_list(unit)

        # Get the list of box neighbours
        box_unit = for l <- ["ABC", "DEF", "GHI"],
            n <- ["123", "456", "789"],
            do: cross(String.codepoints(l), String.codepoints(n)) |> List.flatten

        %{
            :rows => row_unit,
            :columns => col_unit,
            :boxes => box_unit
        }
    end

end
