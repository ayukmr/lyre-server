module Lyre
  # chess database
  class Database
    # create database
    def initialize(db)
      @db = db
    end

    # get sample of database
    def sample(game_id)
      {
        game:   game(game_id),
        pieces: pieces(game_id),
        check: {
          white: in_check?(game_id, 'white'),
          black: in_check?(game_id, 'black')
        }
      }
    end

    # get game by id
    def game(id)
      @db[:games].where(id:).first
    end

    # update turn
    def next_turn(id)
      turn = game(id)[:turn] == 'white' ? 'black' : 'white'

      @db[:games]
        .where(id:)
        .update(turn:)
    end

    # needs to promote
    def promoting(id)
      @db[:games]
        .where(id:)
        .update(promoting: true)
    end

    # needs to promote
    def promoted(id)
      @db[:games]
        .where(id:)
        .update(promoting: false)
    end

    # get piece by id
    def piece(game, id)
      @db[:pieces]
        .where(game:, id:)
        .first
    end

    # get piece at position
    def piece_pos(game, pos_x, pos_y)
      @db[:pieces]
        .where(game:, pos_x:, pos_y:)
        .first
    end

    # get all pieces
    def pieces(game)
      @db[:pieces].where(game:).all
    end

    # check if in check
    def in_check?(game, color)
      king =
        @db[:pieces]
        .where(game:, type: 'king', color:)
        .first
      king_pos = [king[:pos_x], king[:pos_y]]

      other = color == 'white' ? 'black' : 'white'

      # check if vision includes king
      @db[:pieces].where(game:, color: other).any? do |piece|
        vision = Lyre::Movement.new(@db, self, game, piece).vision
        vision.include?(king_pos)
      end
    end

    # check if in checkmate
    def checkmate?(game)
      # white checkmate
      white =
        @db[:pieces].where(game:, color: 'white').none? do |piece|
          !Lyre::Movement.new(@db, self, game, piece).movement.empty?
        end

      # black checkmate
      black =
        @db[:pieces].where(game:, color: 'black').none? do |piece|
          !Lyre::Movement.new(@db, self, game, piece).movement.empty?
        end

      { white:, black: }
    end

    # move piece to position
    def move_piece(game, piece, pos_x, pos_y)
      # remove old piece
      if piece_pos(game, pos_x, pos_y)
        @db[:pieces]
          .where(game:, pos_x:, pos_y:)
          .delete
      end

      from_x = piece[:pos_x]
      from_y = piece[:pos_y]

      new_piece =
        piece.merge(
          pos_x:,
          pos_y:,
          moved: true
        )

      # update piece position
      @db[:pieces]
        .where(game:, pos_x: from_x, pos_y: from_y)
        .update(new_piece)

      return unless piece[:type] == 'king' && !piece[:moved] && (from_x - pos_x).abs == 2

      rook_from_x = {
        6 => 7,
        2 => 0
      }[pos_x]

      rook_to = {
        6 => 5,
        2 => 3
      }[pos_x]

      @db[:pieces]
        .where(game:, pos_x: rook_from_x, pos_y:)
        .update(pos_x: rook_to)
    end
  end
end
