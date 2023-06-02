module Lyre
  # sinatra app
  class App < Sinatra::Base
    # sqlite database
    DB  = Sequel.sqlite('database.db')
    LDB = Lyre::Database.new(DB)

    DB.create_table? :users do
      String :id, primary_key: true
      String :name
      String :token
    end

    # create games table
    DB.create_table? :games do
      String :id, primary_key: true

      String :white
      String :black

      String  :turn
      Boolean :promoting
    end

    # create pieces table
    DB.create_table? :pieces do
      String :id, primary_key: true
      String :game

      String :type
      String :color

      Integer :pos_x
      Integer :pos_y

      Boolean :moved
    end

    DB[:users].insert(id: 'hello', name: 'hello', token: 'hello')
    DB[:users].insert(id: 'world', name: 'world', token: 'world')

    DB[:games].insert(id: 'hello', white: 'hello', black: 'world', turn: 'white')
    Lyre::Pieces.new(DB[:pieces], 'hello').insert

    # set content type
    set :default_content_type, :json

    # cross origin resource sharing
    before do
      headers['Access-Control-Allow-Origin']  = '*'
      headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    end

    # options for all routes
    options '*' do
      response.headers['Allow'] = 'HEAD, GET, POST, PUT, PATCH, DELETE, OPTIONS'
      response.headers['Access-Control-Allow-Headers'] =
        'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Authorization'
    end

    helpers do
      # halt with message
      def message_halt(message, code = 400)
        halt code, { message: }.to_json
      end

      # authorize user
      def authorize_user
        message_halt 'token not present', 401 \
          unless request.env['HTTP_AUTHORIZATION']

        # slice header
        token = request.env['HTTP_AUTHORIZATION']
        token.slice!('Bearer ')

        # get user
        user_id =
          DB[:users]
          .select(:id)
          .where(token:)
          .first

        message_halt 'token is invalid', 401 unless user_id
        user_id[:id]
      end

      # ensure user is in game
      def authorize_game_user(game_id)
        user_id = authorize_user

        # ensure user is in game
        game = LDB.game(game_id)
        message_halt 'user not in game' \
          if game[:white] != user_id && game[:black] != user_id

        user_id
      end
    end

    # get game by id
    get '/game/:game_id' do |game_id|
      authorize_game_user(game_id)
      LDB.sample(game_id).to_json
    end

    # get movement for piece
    get '/game/:game_id/piece/:piece_id/movement' do |game_id, piece_id|
      user_id = authorize_game_user(game_id)

      game  = LDB.game(game_id)
      piece = LDB.piece(game_id, piece_id)

      if !game[:promoting] && game[game[:turn].to_sym] == user_id
        # get movement
        Lyre::Movement
          .new(DB, LDB, game_id, piece)
          .movement
      else
        []
      end.to_json
    end

    # execute move for piece
    put '/game/:game_id/piece/:piece_id/move' do |game_id, piece_id|
      user_id = authorize_game_user(game_id)

      move = JSON.parse(request.body.read)

      game  = LDB.game(game_id)
      piece = LDB.piece(game_id, piece_id)

      message_halt 'wrong color piece for player' \
        unless game[piece[:color].to_sym] == user_id

      message_halt 'wrong turn for moving piece' \
        unless !game[:promoting] && game[game[:turn].to_sym] == user_id

      # validate move
      valid =
        Lyre::Movement
        .new(DB, LDB, game_id, piece)
        .movement
        .include?([move['destX'], move['destY']])

      message_halt 'invalid move destination' unless valid

      # execute move
      LDB.move_piece(
        game_id,
        piece,
        move['destX'],
        move['destY']
      )

      # check if promoting
      promoting =
        piece[:type] == 'pawn' && (
          (piece[:color] == 'white' && move['destY'].zero?) ||
          (piece[:color] == 'black' && move['destY'] == 7)
        )

      if promoting
        LDB.promoting(game_id)
      else
        LDB.next_turn(game_id)
      end

      LDB.sample(game_id).to_json
    end

    # promote pawn
    put '/game/:game_id/piece/:piece_id/promote' do |game_id, piece_id|
      user_id = authorize_game_user(game_id)

      piece_type = JSON.parse(request.body.read)['type']

      game  = LDB.game(game_id)
      piece = LDB.piece(game_id, piece_id)

      message_halt 'wrong color piece for player' \
        unless game[piece[:color].to_sym] == user_id

      message_halt 'wrong turn for promoting piece' \
        unless game[:promoting] && game[game[:turn].to_sym] == user_id

      # validate promotion type
      message_halt 'invalid promotion type' \
        unless %w[bishop knight rook queen].include?(piece_type)

      color = piece[:color]
      pos_y = piece[:pos_y]

      # validate promotion
      valid =
        piece[:type] == 'pawn' && (
          (color == 'white' && pos_y.zero?) ||
          (color == 'black' && pos_y == 7)
        )

      message_halt 'invalid piece promotion' unless valid

      # promote piece
      DB[:pieces]
        .where(game: game_id, id: piece_id)
        .update(type: piece_type)

      LDB.next_turn(game_id)
      LDB.promoted(game_id)

      LDB.sample(game_id).to_json
    end
  end
end
