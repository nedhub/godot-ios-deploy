# test.gd
extends SceneTree


class _Nil_ extends Object:
	func __no_way_any_object_has_this_method():
		return false

var _nil_ = _Nil_.new()

func __is_Nil__(o):
	if typeof(o) == TYPE_OBJECT:
		if o.has_method('__no_way_any_object_has_this_method'):
			return true
	return false

var _p_indent = 0
var _p_sep = ' '
func indent(): _p_indent += 1
func dedent(): _p_indent -= 1
func p(arg0=_nil_, arg1=_nil_, arg2=_nil_, arg3=_nil_, arg4=_nil_, arg5=_nil_, arg6=_nil_):
	var out = ''
	var args = [arg0, arg1, arg2, arg3, arg4, arg5, arg6]
	for i in range(0, args.size()):
		var arg = args[i]
		if __is_Nil__(arg):
			break

		var sep = _p_sep
		if i == 0: sep = ''
		
		var t = typeof(arg)
		if t == TYPE_STRING:
			out += sep + arg
		elif t == TYPE_NIL:
			out += sep + '(null)'
		else:
			out += sep + str(arg)
	for i in range(0, _p_indent):
		out = '  ' + out
	print(out)



# ------------------------------------------------------------------------------
#                                   Testing Tools
# ------------------------------------------------------------------------------


signal wait_test_signal(name)


var _signals_waiting = 0
var _failed_tests = []
var _failed_assertions = 0

func a(assertion, success_msg='', fail_msg=''):
	p('Success: '+success_msg if assertion else 'Failure: '+fail_msg)
	if not assertion: _failed_assertions += 1

func ae(a, b, smsg='%s == %s', fmsg='%s != %s'):
	a(a == b, smsg %[a,b], fmsg%[a,b])

func ane(a, b, smsg='%s != %s', fmsg='%s == %s'):
	a(a != b, smsg %[a,b], fmsg%[a,b])


func wait_for(name):
	_signals_waiting += 1


var _prep_method_map = {}
func find_test_prep(test_method):
	# method fmt = test_{group}_test_name
	# prep fmt   = _prepare_{group}
	var parts = test_method.split('_', false)
	if not parts.size() >= 2:
		return null
	var group = parts[1]
	if _prep_method_map.has(group):
		return _prep_method_map[group]
	var prep = '_prepare_%s'%group
	for method in get_method_list():
		if method.name == prep:
			_prep_method_map[group] = prep
			return prep
	return null


func run_tests():
	for method in get_method_list():
		if method.flags == 65 and method.name.begins_with('test_'):
			_failed_assertions = 0
			print('\n---------- Running %s ----------' % method.name)
			
			indent()
			
			var test_prep = find_test_prep(method.name)
			if test_prep != null:
				call(method.name, call(test_prep))
			else:
				call(method.name)
			if _failed_assertions > 0:
				p(method.name, 'has __FAILED__')
				_failed_tests.append(method.name)
			else:
				p(method.name, 'has __SUCCEEDED__')
			dedent()
	
	print('\n------------ Failed Tests -------------')
	for test in _failed_tests:
		print('\t', test)
	print('---------------------------------------\n')


func _wait_test_signal_callback(name):
	_signals_waiting -= 1

func _initialize():
	connect('wait_test_signal', self, '_wait_test_signal_callback')
	run_tests()
	while _signals_waiting > 0:
		print('Waiting Signals: ', _signals_waiting)
		yield(self, 'wait_test_signal')
	# _nil_.free()
	quit()


# ------------------------------------------------------------------------------
#                                       Tests
# ------------------------------------------------------------------------------


const stc = preload('res://addons/com.indicainkwell.iosdeploy/scripts/static.gd')

var Regex = stc.get_gdscript('regex.gd')
var Shell = stc.get_gdscript('shell.gd')
var iOSExportTemplate = stc.get_gdscript('xcode/ios_export_template.gd')
var iOSDeploy = stc.get_gdscript('xcode/ios_deploy.gd')
var Xcode = stc.get_gdscript('xcode.gd')
var ProvisionFinder = stc.get_gdscript('xcode/finders/provision_finder.gd')
var PBX = stc.get_gdscript('xcode/pbx.gd')


# -- Test Static


func test_static_paths():
	p(stc.get_project_path())
	p(stc.get_project_dir_name())
	p(stc.get_data_path())
	p(stc.globalize_path(stc.get_data_path()))
	p(stc.globalize_path('res://'))
	p(stc.globalize_path('user://'))


# -- Test Logger

func test_logger_add_module():
	var l = stc.get_logger()
	l.add_module('test')
	for logT in ['info', 'warn', 'error']:
		l.call(logT, 'Test ' + logT, 'test')


func test_logger_get_module():
	var l = stc.get_logger()
	var m = l.get_module('test').get_name()
	for logT in ['info', 'warn', 'error']:
		l.call(logT, 'Test ' + logT, m)
	
	m = l.get_module('no.mod.test').get_name()
	for logT in ['info', 'warn', 'error']:
		l.call(logT, 'Test ' + logT, m)


func test_module_logger():
	var l = stc.get_logger().make_module_logger('modlog')
	l.info('hello world')
	l.error('hello world')


# -- Test Shell


func test_shell():
	var _shell = Shell.new()
	var res = _shell.execute('echo', ['Hello World'])
	ae(res.output[0], 'Hello World\n')


var echo
func test_shell_async():
	var _shell = Shell.new()
	echo = _shell.make_command('echo')
	echo.run_async(['Hello World'], self, '_test_shell_async_callback')
	wait_for('_test_shell_async_callback')
	echo.wait()


func _test_shell_async_callback(command, result):
	p('--- Async Shell Output ---')
	p('command', command, ' -- result', result.output)
	ae(result.output[0], 'Hello World\n')
	emit_signal('wait_test_signal', '_test_shell_async_callback')


# -- Test Regex


func _prepare_regex():
	var r = Regex.new()
	var err = r.compile("Found (\\w*) \\((.*)\\) a\\.k\\.a\\. '(.*)' connected through (\\w*)\\.")
	ae(err, OK)
	return r


func test_regex_compile_group_count(r):
	ae(r.get_group_count(), 5)


func test_regex_capture(r):
	var id = 'MyIPhoneID1182Aaab32839abbcadeeff'
	var types = 'iphoneos, iPhone 19, arm'
	var name = 'Some Awesome Phone\'s Name'
	var conn = 'USB'

	var string = "Found %s (%s) a.k.a. '%s' connected through %s."%[id, types, name, conn]
	var captures = r.search(string)
	ae(captures.size(), 5)
	ae(captures[0], string)
	ae(captures[1], id)
	ae(captures[2], types)
	ae(captures[3], name)
	ae(captures[4], conn)



func test_regex_no_capture(r):
	var captures = r.search("[....] Waiting up to 5 seconds for device to find.")
	for cap in captures:
		ae(cap, '')


# -- Test Provision Finder


func _prepare_provisionfinder():
	var finder = ProvisionFinder.new()
	finder._provisions_path = stc.globalize_path('res://tests/files/provisions')
	return finder


func test_provisionfinder_date_parse(f):
	var datefmt = '%s-%s-%sT%s:%s:%sZ'
	var year = 2000
	var month = 11
	var day = 20
	var hour = 20
	var mint = 45
	var sec = 50
	var date = datefmt%[year,month,day,hour,mint,sec]
	var expected_date_dict = f._date_make_dict(year,month,day,hour,mint,sec)
	p('First Date: ', date)

	var date_dict = f._date_parse(date)
	var date_keys = date_dict.keys()
	a(expected_date_dict.has_all(date_keys))
	a(date_dict.has_all(expected_date_dict.keys()))
	for key in date_keys:
		p(key); indent()
		ae(expected_date_dict[key], date_dict[key])
		dedent()


func test_provisionfinder_find_provisions(f):
	var provisions = f.find()
	ae(provisions.size(), 1)
	var prv = provisions[0]
	p('Identity'); indent()
	ae(prv.id, 'uuiduuid-uuid-uuid-uuid-uuiduuiduuid')
	ae(prv.name, 'name')
	ae(prv.app_id, 'appIDPrefix.com.application.identifier')
	ae(prv.app_id_name, 'appIDName')
	dedent()

	p('Platforms'); indent()
	ae(prv.platforms.size(), 1)
	ae(prv.platforms[0], 'iOS')
	dedent()

	p('Team Id'); indent()
	ae(prv.team_ids.size(), 1)
	ae(prv.team_ids[0], 'appIDPrefix')
	dedent()

	p('Creation Date'); indent()
	var date = prv.creation_date
	ae(date.year, 2018)
	ae(date.month, 4)
	ae(date.day, 8)
	ae(date.hour, 1)
	ae(date.minute, 41)
	ae(date.second, 57)
	dedent()

	p('Expiration Date'); indent()
	date = prv.expiration_date
	ae(date.year, 2019)
	ae(date.month, 4)
	ae(date.day, 8)
	ae(date.hour, 1)
	ae(date.minute, 41)
	ae(date.second, 57)
	dedent()


# -- Test PBX


func test_pbx():
	var pbx = PBX.new()
	ae(pbx.open('res://tests/files/pbxprojs/source/project.pbxproj'), OK)
	pbx.add_object('the_uuid_my_butt', 'my_type', {
		property = 'Hello World',
		another = 'Poop',
		onemore = 'omg'
	})
	var d = pbx.get_dict()
	for key in d:
		print(key)
		if typeof(d[key]) == TYPE_DICTIONARY:
			for k in d[key]:
				print('\t', k)
				print('\t\t', d[key][k])
		else:
			print('\t', d[key])
	pbx.save_plist('res://tests/files/pbxprojs/destination/project.pbxproj')


# -- Tes iOSDeploy


func test_iosDeploy():
	var deploy = iOSDeploy.new()
	deploy.bundle = 'hello.app'
	var launch_args = deploy._build_launch_args('DEVICE_ID')
	p('launch_args:', launch_args)
	var deploy_cmd = deploy._build_deploy_cmd(launch_args)
	p('deploy_cmd:', deploy_cmd)
	var joined = deploy._bashinit + [deploy_cmd]
	p('joined_args:', joined)


var deploy
func test_iosDeploy_install():
	deploy = iOSDeploy.new()
	deploy.bundle = 'hello.app'
	deploy.connect('deployed', self, '_test_iosDeploy_install_callback')
	deploy.launch_on('DEVICE_ID')
	wait_for('_test_iosDeploy_install_callback')


func _test_iosDeploy_install_callback(iosdeploy, result, device_id):
	emit_signal('wait_test_signal', '_test_iosDeploy_install_callback')
	p('DEVICE_ID:', device_id)
	p('Result:', result)


# --  Test iOSExportTemplate


func test_iosExportTemplate_destination_path():
	var temp = iOSExportTemplate.new()
	p(temp.get_destination_path())


# --  Test Xcode Project


func test_xcodeproject_make():
	var proj = Xcode.new().make_project('com.my.bundle.id', 'MyTestProject')
	ane(proj, null)


func test_xcodeproject_paths():
	var proj = Xcode.new().make_project('com.my.bundle.id', 'MyTestProject')
	p(proj.get_path())
	p(proj.get_xcodeproj_path())
	p(proj.get_app_path())
	p(proj.get_pbx_path())
	p(proj.get_info_plist_path())



func _test_xcodeproject_build():
	var proj = Xcode.new().make_project('com.my.bundle.id', 'MyTestProject')
	var team = stc.get_gdscript('xcode/finders/team_finder.gd').Team.new()
	team.id = 'TeamID'
	team.name = 'TeamName'
	proj.team = team
	proj.build()
