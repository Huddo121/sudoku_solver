import SudokuSolver

puzzle_text = "..3.2.6..9..3.5..1..18.64....81.29..7.......8..67.82....26.95..8..2.3..9..5.1.3.."
{_, solution} = parse_grid(puzzle_text)
IO.puts display(solution)