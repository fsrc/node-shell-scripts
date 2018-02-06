require! {
  \fs            : { read-file }
  \path          : { join }
  \prelude-ls    : { tail, any, drop, obj-to-pairs, find, map, keys, values }
  \child_process : { spawn }
}

say = console.log


read-state-file = (path, callback) ->
  file  = join(path, 'Local State')

  err, text <- read-file(file, encoding:\utf8)

  if err?
    callback new Error("Error - Can't find 'Local State' (#{file}) file in chromium config directory")

  else
    callback null, JSON.parse(text)



profile-usernames = (path, callback) ->
  err, local-state <- read-state-file path

  if err?
    callback(err)

  else
    usernames = local-state.profile.info_cache
    |> values
    |> map (.user_name)

    callback(null, usernames)

profile-for-username = (path, username, callback) ->
  err, local-state <- read-state-file path

  if err?
    callback(err)

  else
    profile = local-state.profile.info_cache
    |> obj-to-pairs
    |> find (pair) ->
      pair.1.user_name == username

    callback(null, profile.0)


open-chromium-with-profile = (profile) ->
  spawn("chromium", ["--profile-directory=#{profile}"], {
    detached: true
    stdio: \ignore
  }).unref!


if-err = (err) ->
  if err?
    say err
    process.exit(255)

is-given = (args-list, name) ->
  args-list
  |> any (itm) -> itm.starts-with(name)

has-value = (args-list, name) ->
  args-list
  |> find (itm) -> itm.starts-with(name)
  |> (itm) ->
    if itm?
      t = itm.split('=')
      |> tail
      t.join("=")

dmenu = (alternatives, dmenu-arguments, callback) ->

  cp = spawn('dmenu', dmenu-arguments)
  cp.stdin.write(alternatives.join(\\n))
  cp.stdin.end()
  cp.stdout.on('data', (data) ->
    callback(data.to-string!))

args-list = process.argv |> drop 2

PATH = "#{process.env.HOME}/.config/chromium"

args =
  list    : is-given(args-list, \--list)
  dmenu   : has-value(args-list, \--dmenu)
  path    : has-value(args-list, \--path)
  profile : has-value(args-list, \--profile)
  open    : is-given(args-list, \--open)
  help    : is-given(args-list, \--help)

args.path = PATH if not args.path?

if args.help
  say """Usage: chromium-profiles [--path=<~/.config/chromium>] [--open | --open=<profile name>] [--dmenu=<dmenu arguments>] [--list] [--help]

Arguments:
  --path=            Define the path where the 'Local State' file is located. Defaults to '~/.config/chromium'.
  --open= | --open   Define what profile to open and open it. Or open whatever profile selected when --list --dmenu.
  --dmenu=           Use dmenu to make a choice. Assign a JSON array to pass arguments to dmenu.
  --list             List profiles available.
  --help             This info.

Examples:
  chromium-profiles --list --dmenu=[] --open   # Will list profiles in dmenu and open the selected in chromium.
  chromium-profiles --list                     # Will list profiles in stdout
  chromium-profiles --open="Profile 1"         # Will open profile 1 in chromium.

Advanced example, passing arguments to dmenu:

  chromium-profiles --list --open --dmenu='["-p", "Chromium", "-fn", "Liberation Mono:pixelsize=12", "-nb", "#2c001e", "-nf", "\#aea79f", "-sf", "\#ffffff", "-sb", "\#dd4814"]'

  """
  process.exit(0)

# If --list
if args.list
  err, usernames <- profile-usernames(PATH)
  if-err(err)
  # AND --dmenu
  if args.dmenu?
    dmenu-arguments = JSON.parse(args.dmenu)

    alternative  <- dmenu usernames, dmenu-arguments
    err, profile <- profile-for-username PATH, alternative.replace(/\n$/, "")
    if-err(err)

    # AND --open
    if args.open
      open-chromium-with-profile profile

    else
      say profile

  else
    usernames |> map (username) -> say username

# If --profile=
else if args.profile?
  err, profile <- profile-for-username(PATH, argument)
  if-err(err)
  # AND --open
  if args.open
    open-chromium-with-profile profile
  else
    say profile

