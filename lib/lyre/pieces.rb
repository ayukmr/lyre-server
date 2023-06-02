module Lyre
  # standard chess pieces
  class Pieces
    # create pieces
    def initialize(db, game)
      @db   = db
      @game = game
    end

    # insert pieces
    def insert
      # white pieces
      piece('rook',   'white', 0, 7)
      piece('knight', 'white', 1, 7)
      piece('bishop', 'white', 2, 7)
      piece('queen',  'white', 3, 7)
      piece('king',   'white', 4, 7)
      piece('bishop', 'white', 5, 7)
      piece('knight', 'white', 6, 7)
      piece('rook',   'white', 7, 7)

      # black pieces
      piece('rook',   'black', 0, 0)
      piece('knight', 'black', 1, 0)
      piece('bishop', 'black', 2, 0)
      piece('queen',  'black', 3, 0)
      piece('king',   'black', 4, 0)
      piece('bishop', 'black', 5, 0)
      piece('knight', 'black', 6, 0)
      piece('rook',   'black', 7, 0)

      # white and black pawns
      8.times do |pos_x|
        piece('pawn', 'white', pos_x, 6)
        piece('pawn', 'black', pos_x, 1)
      end
    end

    # create piece
    def piece(type, color, pos_x, pos_y)
      @db.insert(
        id: SecureRandom.hex,
        type:,
        color:,
        pos_x:,
        pos_y:,
        game:  @game,
        moved: false
      )
    end
  end
end
