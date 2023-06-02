module Lyre
  # piece movement
  class Movement
    # create movement
    def initialize(db, ldb, game, piece)
      # database
      @db  = db
      @ldb = ldb

      # full data
      @game  = game
      @piece = piece

      # piece type
      @type  = piece[:type]
      @color = piece[:color]

      # position
      @pos_x = piece[:pos_x]
      @pos_y = piece[:pos_y]

      # has moved
      @moved = piece[:moved]
    end

    # movement for piece
    def movement
      vision.filter do |move|
        in_check = false

        @db.transaction do
          # rollback transaction
          @db.rollback_on_exit

          # move piece to move
          move_x, move_y = move
          @ldb.move_piece(@game, @piece, move_x, move_y)

          in_check = @ldb.in_check?(@game, @color)
        end

        !in_check
      end
    end

    # vision for piece
    def vision
      case @type
      when 'pawn'
        pawn_movement

      when 'bishop'
        bishop_movement

      when 'knight'
        knight_movement

      when 'rook'
        rook_movement

      when 'queen'
        # bishop and rook movement
        bishop_movement.concat(rook_movement)

      when 'king'
        king_movement
      end
    end

    # get piece at position
    def piece(pos)
      pos_x, pos_y = pos
      @ldb.piece_pos(@game, pos_x, pos_y)
    end

    # check if move is on board
    def on_board?(move)
      move_x, move_y = move

      move_x >= 0   &&
        move_y >= 0 &&
        move_x < 8  &&
        move_y < 8
    end

    # process movement for knights and king
    def process_movement(movement)
      movement
        .map { |move| canonicalize(move) }
        .filter do |move|
          on_board?(move) && (
            !piece(move) ||
            piece(move)[:color] != @color
          )
        end
    end

    # make move absolute
    def canonicalize(move)
      [
        move[0] + @pos_x,
        move[1] + @pos_y
      ]
    end

    # make movement absolute
    def canonicalize_movement(movement)
      movement.map do |move|
        canonicalize(move)
      end
    end

    # mapping for bishops and rooks
    def sign_map(signs)
      # iterate through signs
      signs.flat_map do |sign|
        # iterate through board width
        (1..7).each_with_object([]) do |delta, moves|
          move = canonicalize(
            [
              delta * sign[0],
              delta * sign[1]
            ]
          )

          if !on_board?(move)
            break moves
          elsif piece(move)
            # add final capturing move
            moves << move if piece(move)[:color] != @color

            break moves
          end

          moves << move
        end
      end
    end

    # movement for pawns
    def pawn_movement
      direction = @color == 'white' ? -1 : 1
      move = canonicalize([0, direction])

      valid_move = on_board?(move) && !piece(move)
      movement   = valid_move ? [move] : []

      # add special pawn movement
      movement.concat(
        pawn_capture,
        pawn_double
      )
    end

    # capturing for pawns
    def pawn_capture
      direction = @color == 'white' ? -1 : 1
      movement  = [[-1, direction], [1, direction]]

      # add capturing conditionally
      movement
        .map { |move| canonicalize(move) }
        .filter do |move|
          on_board?(move) &&
            piece(move) &&
            piece(move)[:color] != @color
        end
    end

    # double move for pawns
    def pawn_double
      direction = @color == 'white' ? -1 : 1

      move_single = canonicalize([0, direction])
      move_double = canonicalize([0, direction * 2])

      # add double movement conditionally
      !@moved && !piece(move_single) && !piece(move_double) ? [move_double] : []
    end

    # movement for bishops
    def bishop_movement
      signs = [
        [-1, -1], [1, 1],
        [-1, 1],  [1, -1]
      ]

      sign_map(signs)
    end

    # movement for knights
    def knight_movement
      movement = [
        [-1, 2], [2, -1],
        [1, 2],  [2, 1],

        [1, -2],  [-2, 1],
        [-1, -2], [-2, -1]
      ]

      process_movement(movement)
    end

    # movement for rooks
    def rook_movement
      signs = [
        [-1, 0], [1, 0],
        [0, -1], [0, 1]
      ]

      sign_map(signs)
    end

    # movement for king
    def king_movement
      movement =
        [
          [-1, -1], [0, -1], [1, -1],
          [-1,  0],          [1,  0],
          [-1,  1], [0, 1],  [1,  1]
        ]

      process_movement(movement).concat(king_castle)
    end

    # castling for king
    def king_castle
      return [] if @moved

      movement =
        [
          [[-2, 0], [-4, 0], (-3..-1)],
          [[2, 0],  [3, 0],  (1..2)]
        ]

      movement.filter! do |(_, rook_pos, tile_xs)|
        # get castling rook
        rook_x, rook_y = canonicalize(rook_pos)
        rook = @ldb.piece_pos(@game, rook_x, rook_y)

        rook && !rook[:moved] &&
          # check for clear tiles
          tile_xs.to_a.none? do |piece_x|
            piece_x, piece_y = canonicalize([piece_x, 0])
            @ldb.piece_pos(@game, piece_x, piece_y)
          end
      end

      movement.map { |(move)| canonicalize(move) }
    end
  end
end
