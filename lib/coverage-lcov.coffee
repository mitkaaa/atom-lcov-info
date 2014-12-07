fs = require 'fs'
parse = require 'lcov-parse'
path = require 'path'

cache = {}
lcovData = null

splitPath = (filePath) ->
  return filePath.replace(/\\/g, '/').split('/')

getCache = (lcovPath) ->
  if data = cache[lcovPath]
    mtime = fs.statSync(lcovPath).mtime.getTime()
    if data.mtime is mtime
      return data

  return

setCache = (lcovPath, data) ->
  total = 0
  covered = 0
  hit = 0
  files = []

  for fileInfo in data
    files.push fdata =
      name: fileInfo.file
      parts: splitPath(fileInfo.file)
      lines: []

    ftotal = 0
    fcovered = 0
    fhit = 0

    for detail in fileInfo.lines.details
      ftotal++

      fdata.lines.push line =
        no: detail.line
        hit: detail.hit
        range: [[detail.line - 1, 0], [detail.line - 1, 0]]

      line.klass = 'lcov-info-no-coverage'
      if line.hit > 0
        line.klass = 'lcov-info-has-coverage'
        fcovered++
        fhit += line.hit

      fdata.total = ftotal
      fdata.covered = fcovered

    fdata.coverage = (if ftotal then fcovered/ftotal else 0)*100
    fdata.hit = fhit
    total += ftotal
    covered += fcovered
    hit += fhit

  cov = (if total then covered/total else 0) * 100
  console.log 'LcovInfoView:', "#{cov.toFixed(2)}% over #{files.length} files"

  return cache[lcovPath] =
    name: lcovPath
    files: files
    total: total
    covered: covered
    coverage: cov
    hit: hit
    mtime: fs.statSync(lcovPath).mtime.getTime()

findInfoFile = (filePath) ->
  while filePath and filePath isnt path.dirname(filePath)
    filename = path.join(filePath, 'coverage', 'lcov.info')

    if fs.existsSync(filename)
      console.log('LcovInfoView: Using info at', filename)
      return filename

    filePath = path.dirname(filePath)

  console.log 'LcovInfoView: No coverage/lcov.info file found for', filePath
  return

matchPath = (fp, lp) ->
  return unless lp.length <= fp.length

  for i in [1..lp.length] by 1
    unless i is 0 and lp[0] is '.'
      if lp[lp.length - i] isnt fp[fp.length - i]
        return false

  return true

mapInfo = (filePath, data, cb) ->
  fileParts = splitPath filePath

  for fileInfo in data.files
    if matchPath(fileParts, fileInfo.parts)
      return cb(fileInfo)

  console.log 'LcovInfoView: No coverage info found for', filePath
  return cb()

getCoverage = (filePath, cb) ->
  unless infoFile = findInfoFile(filePath)
    return cb()

  if lcovData = getCache(infoFile)
    return mapInfo(filePath, lcovData, cb)

  parse infoFile, (err, data) ->
    if err
      console.error 'LcovinfoView:', err
      return cb()

    lcovData = setCache(infoFile, data)
    mapInfo(filePath, lcovData, cb)

  return

getLcov = ->
  console.log lcovData
  return lcovData

module.exports =
  getCoverage: getCoverage
  getLcov: getLcov
