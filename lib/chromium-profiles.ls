require! {
  \fs            : { read-file }
  \path          : { join }
  \prelude-ls    : { any, drop, obj-to-pairs, find, map, keys, values }
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
  |> (itm) -> itm.split('=').1 if itm?

dmenu = (alternatives, callback) ->
  cp = spawn('dmenu', [])
  cp.stdin.write(alternatives.join(\\n))
  cp.stdin.end()
  cp.stdout.on('data', (data) ->
    callback(data.to-string!))

args-list = process.argv |> drop 2

PATH = "#{process.env.HOME}/.config/chromium"

args =
  list    : is-given(args-list, \--list)
  dmenu   : is-given(args-list, \--dmenu)
  path    : has-value(args-list, \--path)
  profile : has-value(args-list, \--profile)
  open    : is-given(args-list, \--open)

args.path = PATH if not args.path?

if args.list
  err, usernames <- profile-usernames(PATH)
  if-err(err)
  if args.dmenu
    alternative <- dmenu usernames
    err, profile <- profile-for-username PATH, alternative.replace(/\n$/, "")
    if-err(err)
    if args.open
      open-chromium-with-profile profile
    else
      say profile
  else
    usernames |> map (username) -> say username

else if args.profile?
  err, profile <- profile-for-username(PATH, argument)
  if-err(err)
  if args.open
    open-chromium-with-profile profile
  else
    say profile

