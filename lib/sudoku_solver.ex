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

end
