# keyboard input
pendingString = ''
collection = null

document.addEventListener 'keypress', (e) ->
  if e.ctrlKey || e.altKey || e.metaKey
    # keyboard shortcut of some kind
    true
  else
    s = translateCharCode(e)
    if s.length != 0
      pendingString += s
    e.preventDefault()

document.addEventListener 'keydown', (e) ->
  if (e.keyCode == 13)
    engage(pendingString)
    pendingString = ''
    e.preventDefault()
  else if (e.keyCode == 8)
    # backspace
    pendingString = pendingString[...-1]
    e.preventDefault()

engage = (str) ->
  if str.length == 0
    return

  direct_message = false

  letters = {}
  for c in str
    if c of letters
      # letter is repeated, we are dealing with a message directly
      direct_message = true
      break
    else
      letters[c] = frequency[c]

  if direct_message
    letters = {}
    for c in str
      if c of letters
        letters[c] += 1
      else
        letters[c] = 1

  collection = new NodeCollection()
  collection.addLeaves(letters, (x: canvas.width/2, y: canvas.height/2))

  return

#
node_style = stroke: 'white', width: 1.5, fill: 'black'
node_emph_style = stroke: 'white', width: 5.5, fill: 'black'
link_style = stroke: 'white', width: 1.5
node_text_style = fill: 'white', font: '32px monospace'

setStyle = (ctx, s) ->
  ctx.fillStyle   = s.fill   if s.fill
  ctx.strokeStyle = s.stroke if s.stroke
  ctx.lineWidth   = s.width  if s.width
  ctx.font        = s.font   if s.font

class Node
  render: (ctx) ->
    ctx.save()
    setStyle(ctx, node_style)
    ctx.beginPath()
    ctx.arc(0,0,@radius,0,Math.PI*2)
    ctx.fill()
    ctx.stroke()
    ctx.restore()

  radius: 15

class Leaf extends Node
  constructor: (@value, @label = '') ->
    
  render: (ctx) ->
    super ctx
    setStyle(ctx, node_text_style)
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'

    if @label.length > 0
      ctx.fillText(@label,0,2*@radius)

    ctx.fillText(@value, 0, 0)

  radius: 32

class NodeCollection
  constructor: () ->
    @nodes = []


  addLeaves: (dict, pos) ->
    length = 0
    for value of dict
      length += 1

    i = 0
    for label, value of dict
      leaf = new Leaf(value, label)
      @nodes.push(leaf)
      leaf.x = pos.x + (i / length - .5 ) * 3 * leaf.radius * length
      leaf.y = pos.y

      i += 1

  render: (ctx) ->
    for n in @nodes
      ctx.save()
      ctx.translate(n.x, n.y)
      n.render(ctx)
      ctx.restore()

      # TODO: render collection handle
# 
canvas = document.getElementById('cnv')
context = canvas.getContext('2d')

render = ->
  context.fillStyle = 'black'
  context.fillRect(0,0, canvas.width,canvas.height)

  if pendingString.length > 0
    context.fillStyle = 'white'
    context.font = '32px monospace'
    context.fillText(pendingString, 0, canvas.height - 32)

  if collection
    collection.render(context)

  window.requestAnimationFrame(render)

window.requestAnimationFrame(render)
