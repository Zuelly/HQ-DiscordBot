module User
  extend Discordrb::Commands::CommandContainer

  command(:id, min_args: 0) do |event, *namearg|
    name = namearg.join(' ') unless namearg.length.zero?
    key = CONFIG['api']

    findid = RestClient.get('https://api-quiz.hype.space/users',
                            params: { q: name },
                            Authorization: key,
                            'Content-Type': :json)

    iddata = JSON.parse(findid)['data']

    if iddata.length.zero?
      begin
        event.channel.send_embed do |embed|
          embed.title = 'Error while searching for stats'
          embed.colour = 'E6286E'
          embed.description = 'Username not found.'
        end
      rescue Discordrb::Errors::NoPermission
        event.respond 'That user doesn\'t exist!'
      end
      break
    end

    id = iddata[0]['userId']

    event.respond "HQ User ID for #{name} is #{id}"
  end

  command(:user, alises: [:stats], min_args: 0) do |event, *namearg|
    keys = JSON.parse(File.read('keys.json'))
    name = namearg.join(' ') unless namearg.length.zero?
    user = BotUser.new(event.user.id)
    if user.exists? && namearg.length.zero?
      profile = user
      name = profile.username
    elsif namearg.length.zero?
      name = event.user.display_name
    end

    key = CONFIG['api']

    extra = false
    if namearg.length.zero? && user.exists? && profile.authkey?
      extra = true
      key = keys[profile.keyid]

      teste = RestClient.get('https://api-quiz.hype.space/users/me',
                             Authorization: key,
                             'Content-Type': :json)

      teste = JSON.parse(teste)

      unless teste['username'].casecmp(profile.username).zero?
        key = CONFIG['api']
        extra = false
        event.respond 'Auth key doesn\'t match your profile username, not returning any extra stats!'
      end
    end

    findid = RestClient.get('https://api-quiz.hype.space/users',
                            params: { q: name },
                            Authorization: key,
                            'Content-Type': :json)

    iddata = JSON.parse(findid)['data']

    if iddata.length.zero?
      begin
        event.channel.send_embed do |embed|
          embed.title = 'Error while searching for stats'
          embed.colour = 'E6286E'
          embed.description = 'Username not found.'
        end
      rescue Discordrb::Errors::NoPermission
        event.respond 'That user doesn\'t exist!'
      end
      break
    end

    id = iddata[0]['userId']

    data = RestClient.get("https://api-quiz.hype.space/users/#{id}",
                          Authorization: key,
                          'Content-Type': :json)

    data = JSON.parse(data)

    leader = data['leaderboard']

    wrank = leader['weekly']['rank']
    arank = leader['alltime']['rank']

    showrank = !(wrank == arank && wrank == 101)

    ranks = []

    wrank = leader['weekly']['rank']
    arank = leader['alltime']['rank']

    if wrank == 101
      hey = "User hasn't won this week"
    else
      prefix = case wrank.to_s.split('').last.to_i
               when 1
                 'st'
               when 2
                 'nd'
               when 3
                 'rd'
               else
                 'th'
               end
      prefix = 'th' if wrank.to_s.length > 1
      hey = "#{wrank}#{prefix}"
    end

    prefix = case arank.to_s.split('').last.to_i
             when 1
               'st'
             when 2
               'nd'
             when 3
               'rd'
             else
               'th'
             end
    prefix = 'th' if arank.to_s.length > 1
    sup = "#{arank}#{prefix}"

    ranks += ["Weekly: #{hey}"]

    ranks += ["All-Time: #{sup}"]

    begin
      event.channel.send_embed do |embed|
        embed.author = { name: "User stats for #{data['username']}" }
        embed.colour = '36399A'

        embed.add_field(name: 'Game Stats', value: [
          "Games Played - #{data['gamesPlayed']}",
          "Win Count - #{data['winCount']}"
        ].join("\n"), inline: true)

        unstat = []

        unstat += [data['leaderboard']['total']]

        unclaimed = data['leaderboard']['unclaimed']
        unstat += [" (#{unclaimed} unclaimed)"] unless unclaimed == '$0'

        embed.add_field(name: 'Amount Won', value: unstat.join("\n"), inline: true)

        embed.add_field(name: 'High Score', value: "#{data['highScore']} questions", inline: true)

        embed.add_field(name: 'Badges', value: "#{data['achievementCount']} badges", inline: true)

        embed.add_field(name: 'Ranking', value: ranks.join("\n"), inline: true) if showrank

        if namearg.length.zero? && user.exists? && extra
          embed.add_field(name: 'Extra Lives', value: "#{data['lives']} Lives", inline: true) if profile.lives?
          if profile.streaks?
            embed.add_field(name: 'Streak Info', value: [
              "#{data['streakInfo']['target'] - data['streakInfo']['current']} days left",
              "#{data['streakInfo']['total']} total streak"
            ].join("\n"), inline: true)
          end
        end

        embed.footer = { text: 'Account created on' }
        embed.timestamp = Time.parse(data['created'])
        embed.thumbnail = { url: data['avatarUrl'].to_s }
      end
    rescue Discordrb::Errors::NoPermission
      event.respond 'Hey, Scott Rogowsky here. I need some memes, dreams, and the ability to embed links! You gotta grant me these permissions!'
    end
  end
end
