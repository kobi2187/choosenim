import httpclient, os, strutils, osproc, uri

import nimblepkg/[cli, tools, version]
import untar

import switcher, common

proc doCmdRaw*(cmd: string) =
  # To keep output in sequence
  stdout.flushFile()
  stderr.flushFile()

  displayDebug("Executing", cmd)
  let (output, exitCode) = execCmdEx(cmd)
  displayDebug("Finished", "with exit code " & $exitCode)
  displayDebug("Output", output)

  if exitCode != QuitSuccess:
    raise newException(ChooseNimError,
        "Execution failed with exit code $1\nCommand: $2\nOutput: $3" %
        [$exitCode, cmd, output])

proc extract*(path: string, extractDir: string) =
  display("Extracting", path.extractFilename(), priority = HighPriority)

  let ext = path.splitFile().ext
  var newPath = path
  case ext
  of ".xz":
    # We need to decompress manually.
    let unxzPath = findExe("unxz")
    if unxzPath.len == 0:
      let msg = "Cannot decompress xz, `unxz` not in PATH"
      raise newException(ChooseNimError, msg)

    let tarFile = newPath.changeFileExt("") # This will remove the .xz
    # `unxz` complains when the .tar file already exists.
    removeFile(tarFile)
    doCmdRaw("unxz \"$1\"" % newPath)
    newPath = tarFile
  of ".gz":
    # untar package will take care of this.
    discard
  else:
    raise newException(ChooseNimError, "Invalid archive format " & ext)

  try:
    var file = newTarFile(newPath)
    file.extract(extractDir)
  except Exception as exc:
    raise newException(ChooseNimError, "Unable to extract. Error was '$1'." %
                       exc.msg)

proc getProxy*(): Proxy =
  ## Returns ``nil`` if no proxy is specified.
  var url = ""
  try:
    if existsEnv("http_proxy"):
      url = getEnv("http_proxy")
    elif existsEnv("https_proxy"):
      url = getEnv("https_proxy")
  except ValueError:
    display("Warning:", "Unable to parse proxy from environment: " &
        getCurrentExceptionMsg(), Warning, HighPriority)

  if url.len > 0:
    var parsed = parseUri(url)
    if parsed.scheme.len == 0 or parsed.hostname.len == 0:
      parsed = parseUri("http://" & url)
    let auth =
      if parsed.username.len > 0: parsed.username & ":" & parsed.password
      else: ""
    return newProxy($parsed, auth)
  else:
    return nil
