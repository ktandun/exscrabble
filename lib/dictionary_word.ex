defmodule DictionaryWord do
  def read_from_file() do
    File.read!("./words.txt")
    |> String.split("\n", trim: true)
    |> Enum.group_by(&String.length/1)
    |> Enum.reduce(%{}, fn {len, words}, acc ->
      Map.put(acc, len, MapSet.new(words))
    end)
  end
end