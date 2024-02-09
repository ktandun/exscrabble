defmodule Board do
  defstruct size: 0,
            hand: "",
            hand_length: "",
            words: [],
            board: [],
            occupied_tiles: MapSet.new(),
            possible_placements: []

  def new(board_string, hand) when is_binary(board_string) and is_binary(hand) do
    board_array =
      board_string
      |> String.split("\n", trim: true)

    board_map =
      board_array
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, row} ->
        line
        |> String.graphemes()
        |> Enum.with_index()
        |> Enum.map(fn {letter, col} ->
          {row, col, letter}
        end)
      end)
      |> Enum.reduce(%{}, fn {y, x, letter}, acc ->
        Map.put(acc, {y, x}, letter)
      end)

    board_size = length(board_array)

    words = get_words(board_array)

    occupied_tiles =
      words
      |> Stream.flat_map(fn word -> word.coordinates end)
      |> MapSet.new()

    hand_length = String.length(hand)

    possible_placements = get_possible_placements(board_size, occupied_tiles, hand_length)

    %Board{
      board: board_map,
      size: board_size,
      words: words,
      occupied_tiles: occupied_tiles,
      possible_placements: possible_placements,
      hand: hand,
      hand_length: hand_length
    }
  end

  def find_possible_words(%Board{} = board, valid_words) do
    hand_combinations = get_hand_combinations(board.hand)

    board.possible_placements
    |> Enum.flat_map(fn {y, x, direction} ->
      min_distance =
        find_min_distance_to_occupied_tile(board.occupied_tiles, board.size, {y, x, direction})

      for word_length <- min_distance..board.hand_length,
          letters <- hand_combinations[word_length] do
        {y, x, direction, letters}
      end
    end)
    |> Enum.map(fn {y, x, direction, letters} ->
      try_place_letters(board, letters, {y, x, direction}, valid_words)
    end)
    |> Enum.filter(fn placement -> placement != nil end)
  end

  #########################
  ### private functions ###
  #########################

  defp get_hand_combinations(hand) do
    graphemes = hand |> String.graphemes()

    1..String.length(hand)
    |> Enum.reduce(%{}, fn len, acc ->
      combinations =
        comb(len, graphemes)
        |> Enum.map(&Enum.join/1)

      Map.put(acc, len, combinations)
    end)
  end

  defp is_valid_word?(word, valid_words) do
    valid_words[word.length]
    |> MapSet.member?(word.word)
  end

  defp try_place_letters(%Board{} = board, letters, {y, x, direction}, valid_words) do
    {new_board_map, _, _} =
      letters
      |> String.graphemes()
      |> Enum.reduce({board.board, y, x}, fn letter, acc ->
        {board_map, curr_y, curr_x} =
          acc

        board_map = Map.put(board_map, {curr_y, curr_x}, letter)

        {next_y, next_x} = get_next_empty_tile(board_map, {curr_y, curr_x}, direction)

        {board_map, next_y, next_x}
      end)

    new_board_words =
      new_board_map
      |> board_map_to_array(board.size)
      |> get_words()

    created_words = new_board_words -- board.words

    main_word = get_created_main_word(created_words, {y, x, direction})

    score = get_board_score_diff(new_board_words, board.words)

    all_valid =
      created_words
      |> Enum.all?(&is_valid_word?(&1, valid_words))

    case all_valid do
      true -> %{:y => y, :x => x, :direction => direction, :word => main_word, :score => score}
      false -> nil
    end
  end

  defp get_board_score_diff(old_board, new_board) do
    # todo: calculate score before and after placing
    0
  end

  def get_created_main_word(board_words, {y, x, direction}) do
    board_words
    |> Enum.find(fn word ->
      word.x == x && word.y == y && word.direction == direction
    end)
  end

  defp get_next_empty_tile(board_map, {y, x}, direction) do
    if Map.get(board_map, {y, x}, ".") == "." do
      {y, x}
    else
      next_tile_fn =
        case direction do
          :h -> fn {row, col} -> {row, col + 1} end
          :v -> fn {row, col} -> {row + 1, col} end
        end

      get_next_empty_tile(board_map, next_tile_fn.({y, x}), direction)
    end
  end

  defp board_map_to_array(board_map, board_size) do
    for y <- 0..board_size, x <- 0..board_size do
      {y, x}
    end
    |> Enum.map(fn {y, x} ->
      Map.get(board_map, {y, x}, "") <> if x == board_size - 1, do: "\n", else: ""
    end)
    |> Enum.join()
    |> String.split("\n", trim: true)
  end

  defp find_min_distance_to_occupied_tile(occupied_tiles, board_size, {y, x, direction}) do
    1..board_size
    |> Enum.find(fn distance ->
      {tile_y, tile_x} =
        case direction do
          :h -> {y, x + distance - 1}
          :v -> {y + distance - 1, x}
        end

      MapSet.new([
        {tile_y + 1, tile_x},
        {tile_y, tile_x + 1},
        {tile_y - 1, tile_x},
        {tile_y, tile_x - 1}
      ])
      |> MapSet.disjoint?(occupied_tiles)
      |> Kernel.not()
    end)
  end

  defp get_possible_placements(board_size, occupied_tiles, hand_length)
       when is_integer(hand_length) do
    for y <- 0..(board_size - 1),
        x <- 0..(board_size - 1) do
      {y, x}
    end
    |> Stream.flat_map(fn {y, x} ->
      h = get_reachable_tiles({y, x}, occupied_tiles, hand_length, :h)
      v = get_reachable_tiles({y, x}, occupied_tiles, hand_length, :v)

      [h, v]
    end)
    |> Stream.filter(fn coord_directions ->
      case coord_directions do
        {y, x, _direction} -> {y, x} not in occupied_tiles
        _ -> false
      end
    end)
    |> MapSet.new()
  end

  defp has_word?(board_line) do
    Regex.match?(~r/[a-zA-Z]{2,}/, board_line)
  end

  defp to_words(board_line) do
    Regex.scan(~r/[a-zA-Z]{2,}/, board_line, return: :index)
    |> List.flatten()
    |> Enum.map(fn {start, length} ->
      string_slice = start..(start + length - 1)

      word = String.slice(board_line, string_slice)

      {word, start}
    end)
  end

  defp transpose(board_array) do
    board_array
    |> Enum.map(&String.graphemes/1)
    |> List.zip()
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(&Enum.join/1)
  end

  defp get_words(board_array) do
    h =
      board_array
      |> Stream.with_index()
      |> Stream.filter(fn {line, _index} -> has_word?(line) end)
      |> Stream.map(fn {line, h_index} ->
        line
        |> to_words
        |> Enum.map(fn {word, v_index} ->
          Word.new(:h, word, h_index, v_index)
        end)
      end)

    v =
      board_array
      |> transpose
      |> Stream.with_index()
      |> Stream.filter(fn {line, _index} -> has_word?(line) end)
      |> Stream.map(fn {line, v_index} ->
        line
        |> to_words
        |> Enum.map(fn {word, h_index} ->
          Word.new(:v, word, h_index, v_index)
        end)
      end)

    h
    |> Stream.concat(v)
    |> Enum.to_list()
    |> List.flatten()
  end

  defp get_reachable_tiles({y, x}, occupied_tiles, distance, :v)
       when is_integer(distance) do
    reachable_tiles =
      for y_coord <- (y - 1)..(y + distance),
          x_coord <- (x - 1)..(x + 1) do
        {y_coord, x_coord}
      end
      |> Stream.filter(fn coord ->
        coord != {y - 1, x - 1} &&
          coord != {y + distance, x - 1} &&
          coord != {y - 1, x + 1} &&
          coord != {y + distance, x + 1}
      end)
      |> MapSet.new()

    case MapSet.disjoint?(reachable_tiles, occupied_tiles) do
      false -> {y, x, :v}
      true -> nil
    end
  end

  defp get_reachable_tiles({y, x}, occupied_tiles, distance, :h)
       when is_integer(distance) do
    reachable_tiles =
      for y_coord <- (y - 1)..(y + 1),
          x_coord <- (x - 1)..(x + distance) do
        {y_coord, x_coord}
      end
      |> Stream.filter(fn coord ->
        coord != {y - 1, x - 1} &&
          coord != {y + 1, x - 1} &&
          coord != {y - 1, x + distance} &&
          coord != {y + 1, x + distance}
      end)
      |> MapSet.new()

    case MapSet.disjoint?(reachable_tiles, occupied_tiles) do
      false -> {y, x, :h}
      true -> nil
    end
  end

  defp comb(0, _), do: [[]]
  defp comb(_, []), do: []

  defp comb(m, [h | t]) do
    for(l <- comb(m - 1, t), do: [h | l]) ++ comb(m, t)
  end
end