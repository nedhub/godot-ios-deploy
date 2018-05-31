# controller.gd
tool
extends Reference


# ------------------------------------------------------------------------------
#                                      Signals
# ------------------------------------------------------------------------------


signal began_pipeline(this)
signal finished_pipeline(this)


# ------------------------------------------------------------------------------
#                                     Constants
# ------------------------------------------------------------------------------


const stc = preload('static.gd')


# ------------------------------------------------------------------------------
#                                     Subtypes
# ------------------------------------------------------------------------------


var Xcode = stc.get_gdscript('xcode.gd')


# ------------------------------------------------------------------------------
#                                      Scenes
# ------------------------------------------------------------------------------


var OneClickButtonScene = stc.get_scene('one_click_deploy_button.tscn')
var SettingsMenuScene = stc.get_scene('deploy_settings_menu.tscn')


# ------------------------------------------------------------------------------
#                                     Variables
# ------------------------------------------------------------------------------


var _xcode = Xcode.new()
var _xcode_project

var _config = ConfigFile.new()

var _one_click_button = OneClickButtonScene.instance()
var _settings_menu = SettingsMenuScene.instance()


# ------------------------------------------------------------------------------
#                                     Overrides
# ------------------------------------------------------------------------------


func _init():
	get_view().set_disabled(true)
	get_view().connect('pressed', self, '_one_click_button_pressed')
	get_view().connect('presenting_hover_menu', self, '_one_click_button_presenting_hover_menu')
	get_view().connect('settings_button_pressed', self, '_one_click_button_settings_button_pressed')

	get_menu().hide()
	get_menu().connect('request_fill', self, '_on_request_fill')
	get_menu().connect('request_populate', self, '_on_request_populate')
	get_menu().connect('edited_team', self, '_on_edited_team')
	get_menu().connect('edited_provision', self, '_on_edited_provision')
	get_menu().connect('edited_bundle_id', self, '_on_edited_bundle_id')
	get_menu().connect('finished_editing', self, '_on_finished_editing')

	# made_project calls set_disabled(false), so this must come after
	# get_view().set_disabled(true) for when project exists and is made
	# immediately
	_xcode.connect('made_project', self, '_on_xcode_made_project')
	if _xcode.make_project_async() == ERR_DOES_NOT_EXIST:
		stc.get_logger().info('Godot iOS Xcode Template Does Not Exist')

# ------------------------------------------------------------------------------
#                                      Methods
# ------------------------------------------------------------------------------


func cleanup():
	get_view().queue_free()
	get_menu().queue_free()


func get_view():
	return _one_click_button


func get_menu():
	return _settings_menu


func valid_bundleid(bundle_id, provision):
	var first_dot_idx = provision.app_id.find('.')
	if first_dot_idx == -1:
		stc.get_logger().warn('Invalid app_id in provision: %s' % provision.to_dict())
		return false

	var prov_bundleid = provision.app_id.right(first_dot_idx + 1)
	return bundle_id.match(prov_bundleid)


func valid_xcode_project():
	return _xcode_project != null and\
	   (_xcode_project.provision != null and\
	    _xcode_project.team      != null)


func filter_provisions(provisions):
	# Filter out
	# - expired
	# - duplicates -- Compare by app_id_name or name? I guess name.
	var valid_provisions = []
	var duplicates = {}
	var today = OS.get_unix_time()
	for provision in provisions:
		var expire = OS.get_unix_time_from_datetime(provision.expiration_date)
		if today > expire: continue
		if not duplicates.has(provision.name):
			duplicates[provision.name] = []
		duplicates[provision.name].append(provision)
		valid_provisions.append(provision)

	# for each duplicate:
	# - check creation_date
	# - keep latest
	# - erase oldest
	for provisions in duplicates.values():
		var latest = provisions[0]
		var latest_t = OS.get_unix_time_from_datetime(latest.creation_date)
		# skip first provision in loop
		for i in range(1, provisions.size()):
			var next = provisions[i]
			var next_t = OS.get_unix_time_from_datetime(next.creation_date)
			if next_t > latest_t:
				valid_provisions.erase(latest)
				latest = next
				latest_t = next_t
			else:
				valid_provisions.erase(next)

	return valid_provisions


func execute_deploy_pipeline():
	# Pipeline: Build Project -> Then Deploy to Devices
	emit_signal('began_pipeline', self)
	_xcode_project.build()


func _initialize_xcode_project(xcode_project):
	xcode_project.connect('built', self, '_on_xcode_project_built')
	xcode_project.connect('deployed', self, '_on_device_deployed')
	if _config.load(stc.get_data_path('config.cfg')) != OK:
		stc.get_logger().info('unable to load config')
	else:
		xcode_project.bundle_id = _config.get_value('xcode/project', 'bundle_id')
		xcode_project.name = _config.get_value('xcode/project', 'name')

		xcode_project.automanaged = _config.get_value('xcode/project', 'automanaged', false)
		xcode_project.debug = _config.get_value('xcode/project', 'debug', true)
		xcode_project.custom_info = _config.get_value('xcode/project', 'custom_info', {})

		var team = _xcode.Team.new()
		team.from_dict(_config.get_value('xcode/project', 'team'))
		xcode_project.team = team

		var provision = _xcode.Provision.new()
		provision.from_dict(_config.get_value('xcode/project', 'provision'))
		xcode_project.provision = provision

		var devices = _config.get_value('xcode/project', 'devices', [])
		for i in range(devices.size()):
			var device = _xcode.Device.new()
			device.from_dict(devices[i])
			devices[i] = device
		xcode_project.set_devices(devices)
	stc.get_logger().debug('Xcode Project App Path: ' + xcode_project.get_app_path())


# ------------------------------------------------------------------------------
#                                     Callbacks
# ------------------------------------------------------------------------------


# -- SettingsMenu


func _on_request_populate(menu):
	menu.populate_devices(_xcode.finder.find_devices())
	menu.populate_provisions(filter_provisions(_xcode.finder.find_provisions()))
	menu.populate_teams(_xcode.finder.find_teams())


func _on_request_fill(menu):
	print('filling')
	menu.fill_devices_group(_xcode_project.get_devices())
	menu.fill_bundle_group(
		_xcode_project.name,
		_xcode_project.bundle_id
	)
	menu.fill_identity_group(
		_xcode_project.team,
		_xcode_project.automanaged,
		_xcode_project.provision
	)


func _on_edited_team(menu, new_team):
	assert(new_team extends _xcode.Team)
	if _xcode_project.team != null and\
	   _xcode_project.team.id == new_team.id and\
	   _xcode_project.team.name == new_team.name:
		   return

	# make sure to set new team
	_xcode_project.team = new_team

	if _xcode_project.provision == null:
		return

	# Notify menu if provision is invalid due to new team
	if not _xcode_project.provision.team_ids.has(new_team.id):
		# provision is invalid as it does not support team
		menu.invalidate_provision()


func _on_edited_provision(menu, new_provision):
	assert(new_provision extends _xcode.Provision)

	if _xcode_project.provision != null and _xcode_project.provision.id == new_provision.id:
		return

	# make sure to set new provision
	_xcode_project.provision = new_provision

	# Notify menu if teams and bundleid are invalid due to new provision

	if _xcode_project.team != null and not new_provision.team_ids.has(_xcode_project.team.id):
		# team is invalid as it is not supported by provision
		menu.invalidate_team()

	# Check bundleid

	if _xcode_project.bundle_id == null or _xcode_project.bundle_id.empty():
		return

	if not valid_bundleid(_xcode_project.bundle_id, new_provision):
		menu.invalidate_bundle_id()


func _on_edited_bundle_id(menu, new_bundle_id):
	_xcode_project.bundle_id = new_bundle_id
	if _xcode_project.provision == null:
		return
	if not valid_bundleid(new_bundle_id, _xcode_project.provision):
		menu.invalidate_bundle_id()


func _on_finished_editing(menu):
	var bundle = menu.get_bundle_group()
	_xcode_project.bundle_id = bundle.id
	_xcode_project.name = bundle.display
	_config.set_value('xcode/project', 'bundle_id', bundle.id)
	_config.set_value('xcode/project', 'name', bundle.display)

	var identity = menu.get_identity_group()
	_xcode_project.team = identity.team
	_xcode_project.provision = identity.provision
	_xcode_project.automanaged = identity.automanaged
	_config.set_value('xcode/project', 'team', identity.team.to_dict())
	_config.set_value('xcode/project', 'provision', identity.provision.to_dict())
	_config.set_value('xcode/project', 'automanaged', identity.automanaged)

	_xcode_project.set_devices(menu.get_active_devices())

	var savable_devices_fmt = []
	for device in _xcode_project.get_devices():
		savable_devices_fmt.append(device.to_dict())
	_config.set_value('xcode/project', 'devices', savable_devices_fmt)

	_xcode_project.update()
	if _config.save(stc.get_data_path('config.cfg')) != OK:
		stc.get_logger().info('unable to save config')


# -- OneClickButton


func _one_click_button_pressed():
	get_menu().show()
	if not valid_xcode_project():
		get_menu().show()
	else:
		execute_deploy_pipeline()


func _one_click_button_presenting_hover_menu(oneclickbutton, menu):
	print('OneClickButton: Presenting Hover Menu')


func _one_click_button_settings_button_pressed(oneclickbutton):
	print('OneClickButton: Settings Button Pressed')
	get_menu().show()


# -- Xcode


func _on_xcode_made_project(xcode, result, project):
	print('Made Xcode Project')
	_xcode_project = project
	_initialize_xcode_project(_xcode_project)
	get_view().set_disabled(false)


# -- XcodeProject


func _on_xcode_project_built(xcode_project, result):
	xcode_project.deploy()


func _on_device_deployed(xcode_project, result, device_id):
	stc.get_logger().debug('DEVICE DEPLOYED: ', xcode_project, result.output, device_id)

	if not xcode_project.is_deploying():
		# this is the last device
		emit_signal('finished_pipeline', self)
