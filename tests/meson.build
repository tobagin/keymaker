# Test executables
test_sources = [
    'test-main.vala',
    'test-utils.vala',
    'test-ssh-operations.vala', 
    'test-rotation.vala',
    'test-tunneling.vala'
]

# Test executable  
test_exe = executable(
    'keymaker-tests',
    test_sources,
    '../src/utils/filesystem.vala',
    '../src/utils/command.vala', 
    '../src/utils/log.vala',
    '../src/utils/settings.vala',
    '../src/models/enums.vala',
    '../src/models/ssh-key.vala',
    '../src/backend/ssh-operations/generation.vala',
    '../src/backend/ssh-operations/metadata.vala',
    '../src/backend/ssh-operations/mutate.vala',
    '../src/backend/rotation/plan.vala',
    '../src/backend/rotation/runner.vala', 
    '../src/backend/rotation/deploy.vala',
    '../src/backend/tunneling/configuration.vala',
    '../src/backend/tunneling/active-tunnel.vala',
    '../src/backend/tunneling/manager.vala',
    config_vala,
    dependencies: [
        gtk_dep,
        adw_dep,
        gio_dep,
        gee_dep,
        json_dep,
        math_dep,
    ],
    vala_args: vala_args,
    c_args: c_args,
    install: false
)

# Register tests
test('utils-test', test_exe, args: ['--test-utils'])
test('ssh-operations-test', test_exe, args: ['--test-ssh-ops'])
test('rotation-test', test_exe, args: ['--test-rotation'])
test('tunneling-test', test_exe, args: ['--test-tunneling'])