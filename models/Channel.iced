fs = require 'fs'
gm = require 'gm'
request = require 'request'

class exports.Channel extends Mikuia.Model
	constructor: (name) ->
		@model = 'channel'
		@name = name.replace('#', '').toLowerCase()

	# Core functions, changing those often end up breaking half of the universe.

	exists: (callback) ->
		await @_exists '', defer err, data
		callback err, data

	getName: () ->
		return @name

	isLive: (callback) ->
		# This is bad D:
		await Mikuia.Database.sismember 'mikuia:streams', @getName(), defer err, data
		callback err, data

	# Info & settings

	getAll: (callback) ->
		await @_hgetall '', defer err, data
		callback err, data

	getInfo: (field, callback) ->
		await @_hget '', field, defer err, data
		callback err, data

	getSetting: (plugin, field, callback) ->
		await @_hget 'plugin:' + plugin + ':settings', field, defer err, data
		if Mikuia.Plugin.getManifest(plugin)?.settings?.channel?[field]?
			setting = Mikuia.Plugin.getManifest(plugin).settings.channel[field]
			if !data && setting.default?
				data = setting.default
			if setting.type == 'boolean'
				if data == 'true'
					data = true
				if data == 'false'
					data = false
		callback err, data

	getSettings: (plugin, callback) ->
		await @_hgetall 'plugin:' + plugin + ':settings', defer err, data
		callback err, data

	setInfo: (field, value, callback) ->
		await @_hset '', field, value, defer err, data
		callback err, data

	setSetting: (plugin, field, value, callback) ->
		if value != ''
			await @_hset 'plugin:' + plugin + ':settings', field, value, defer err, data
		else
			await @_hdel 'plugin:' + plugin + ':settings', field, defer err, data
		callback err, data

	# Enabling & disabling, whatever.

	disable: (callback) ->
		await
			Mikuia.Database.srem 'mikuia:channels', @getName(), defer err, data
			Mikuia.Chat.part '#' + @getName()
		callback err, data

	enable: (callback) ->
		await
			Mikuia.Database.sadd 'mikuia:channels', @getName(), defer err, data
			Mikuia.Chat.join '#' + @getName()
		callback err, data

	isEnabled: (callback) ->
		await Mikuia.Database.sismember 'mikuia:channels', @getName(), defer err, data
		callback err, data

	# Commands

	addCommand: (command, handler, callback) ->
		await @_hset 'commands', command, handler, defer err, data
		callback err, data

	getCommand: (command, callback) ->
		await @_hget 'commands', command, defer err, data
		callback err, data

	getCommandSettings: (command, defaults, callback) ->
		await
			@_hgetall 'command:' + command, defer err, settings
			@getCommand command, defer commandError, handler

		if defaults && !commandError && Mikuia.Plugin.getHandler(handler)?.settings?
			if !settings?
				settings = {}
			for settingName, setting of Mikuia.Plugin.getHandler(handler).settings
				if !settings[settingName]?
					settings[settingName] = setting.default

		callback err, settings

	getCommands: (callback) ->
		await @_hgetall 'commands', defer err, data
		callback err, data

	removeCommand: (command, callback) ->
		await @_hdel 'commands', command, defer err, data
		callback err, data

	setCommandSetting: (command, key, value, callback) ->
		if value != ''
			await @_hset 'command:' + command, key, value, defer err, data
		else
			await @_hdel 'command:' + command, key, defer err, data
		callback err, data

	# Plugins

	disablePlugin: (name, callback) ->
		await @_srem 'plugins', name, defer err, data
		callback err, data

	enablePlugin: (name, callback) ->
		await @_sadd 'plugins', name, defer err, data
		callback err, data

	getEnabledPlugins: (callback) ->
		await @_smembers 'plugins', defer err, data
		callback err, data

	isPluginEnabled: (name, callback) ->
		await @_sismember 'plugins', name, defer err, data
		callback err, data

	# "Convenience" functions that help get and set data...  or something.

	getBio: (callback) ->
		await @getInfo 'bio', defer err, data
		callback err, data

	getDisplayName: (callback) ->
		await @getInfo 'display_name', defer err, data
		if err || data == null
			callback false, @getName()
		else
			callback err, data

	getEmail: (callback) ->
		await @getInfo 'email', defer err, data
		callback err, data

	getLogo: (callback) ->
		await @getInfo 'logo', defer err, data
		callback err, data

	setBio: (bio, callback) ->
		await @setInfo 'bio', bio, defer err, data
		callback err, data

	setDisplayName: (name, callback) ->
		await @setInfo 'display_name', name, defer err, data
		callback err, data

	setEmail: (email, callback) ->
		await @setInfo 'email', email, defer err, data
		callback err, data

	setLogo: (logo, callback) ->
		await @setInfo 'logo', logo, defer err, data
		callback err, data

	# :D

	updateAvatar: (callback) ->
		randomNumber = Math.floor(Math.random() * 10000000)
		await @getInfo 'logo', defer err, logo
		if !err && logo.indexOf('http://') > -1
			path = 'web/public/img/avatars/' + @getName() + '.jpg'
			r = request.get(logo).pipe fs.createWriteStream path
			r.on 'finish', ->
				console.log 'i am here'
				gm(path).resize(64, 64).write(path, (err) ->
					console.log err
					callback err
				)
		else
			callback true