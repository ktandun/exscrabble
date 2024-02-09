defmodule Word do
  @enforce_keys [:word, :y, :x, :direction, :length, :coordinates, :sorted]
  defstruct [:word, :y, :x, :direction, :length, :coordinates, :sorted]

  def new(direction, word, y, x) do
    wordlength = String.length(word)

    coordinates =
      case direction do
        :h -> for x_coord <- x..(x + wordlength - 1), do: {y, x_coord}
        :v -> for y_coord <- y..(y + wordlength - 1), do: {y_coord, x}
      end

    %Word{
      :direction => direction,
      :word => word,
      :sorted => word |> String.graphemes() |> Enum.sort() |> Enum.join(),
      :y => y,
      :x => x,
      :length => wordlength,
      :coordinates => coordinates
    }
  end

  def is_valid_word?(%Word{} = word, valid_words) do
    valid_words[word.length]
    |> MapSet.member?(word.word)
  end
end