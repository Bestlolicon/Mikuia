###
  Hello, and welcome to the land of crazy stuff! (AKA Mikuia)
  This time, I'll try to comment at least a bit of this code...
  Let's see how it goes.  
###

cli = require 'cli-color'
fs = require 'fs'
path = require 'path'

# So yeah, let's see what happens if we go with this.
{EventEmitter} = require 'events'

Mikuia =
	Events: new EventEmitter
	Models: {}
	settings: {}

global.Mikuia = Mikuia

# Loading core files (that's my way of pretending everything is okay)
for fileName in fs.readdirSync 'core'
	filePath = path.resolve './', 'core', fileName
	coreFile = require filePath
	shortName = fileName.replace '.iced', ''
	Mikuia[shortName] = new coreFile[shortName] Mikuia

# Models... at least that's how I call this weird stuff.
for fileName in fs.readdirSync 'models'
	filePath = path.resolve './', 'models', fileName
	modelFile = require filePath
	shortName = fileName.replace '.iced', ''
	Mikuia.Models[shortName] = modelFile[shortName]

# Let's load the settings!
Mikuia.Settings.read ->
	# Welp, we have our settings ready, we can now slowly check stuff, and launch!
	# First thing to check - database connection, Redis FTW.
	# CoffeeScript makes this line look really weird :D
	Mikuia.Database.connect Mikuia.settings.redis.host, Mikuia.settings.redis.port, Mikuia.settings.redis.options

	# Let's load plugins.
	fs.readdir 'plugins', (pluginDirErr, fileList) ->
		if pluginDirErr
			Mikuia.Log.warning 'Can\'t access plugin directory.'
		else
			Mikuia.Log.info 'Found ' + cli.greenBright(fileList.length) + ' directories in plugin directory.'
			
		for file in fileList
			Mikuia.Plugin.load file
		
	Mikuia.Chat.connect()
	Mikuia.Twitch.init()
	Mikuia.Chat.update()

	Mikuia.Web = require './web/web.iced'