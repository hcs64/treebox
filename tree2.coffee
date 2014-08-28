# keyboard input
pendingString = ''
collections = []

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

  shapes = ['circle','square','diamond']
  collection = new NodeCollection(shapes[collections.length % shapes.length])
  collection.addLeaves(letters, (x: canvas.width/2, y: canvas.height/2))
  collections.push(collection)

  return

#
node_style = stroke: 'white', width: 1.5, fill: 'black'
node_emph_style = stroke: 'white', width: 5.5, fill: 'black'
link_style = stroke: 'white', width: 1.5
light_link_style = stroke: 'white', width: .5
node_text_style = fill: 'white', font: '16px monospace'

setStyle = (ctx, s) ->
  ctx.fillStyle   = s.fill   if s.fill
  ctx.strokeStyle = s.stroke if s.stroke
  ctx.lineWidth   = s.width  if s.width
  ctx.font        = s.font   if s.font

renderShape = (ctx, shape, radius) ->
  switch shape
    when 'circle'
      ctx.arc(0,0,radius,0,Math.PI*2)
    when 'square'
      ctx.moveTo(-radius,-radius)
      ctx.lineTo(-radius,+radius)
      ctx.lineTo(+radius,+radius)
      ctx.lineTo(+radius,-radius)
      ctx.closePath()
    when 'diamond'
      ctx.moveTo(-radius*Math.SQRT2,0)
      ctx.lineTo(0,+radius*Math.SQRT2)
      ctx.lineTo(+radius*Math.SQRT2,0)
      ctx.lineTo(0,-radius*Math.SQRT2)
      ctx.closePath()

  return

default_node_radius = 15

class Node
  render: (ctx) ->
    ctx.save()
    ctx.translate(@x, @y)
    setStyle(ctx, node_style)
    ctx.beginPath()
    renderShape(ctx, @shape, @radius)
    ctx.fill()
    ctx.stroke()
    ctx.restore()

  isHit: (pos) ->
    dx = @x - pos.x
    dy = @y - pos.y

    (dx*dx + dy*dy < @radius*@radius)

  forAll: (fn) ->
    fn(this)
    return

  tryAll: (fn) ->
    return fn(this)

  radius: default_node_radius

class Leaf extends Node
  constructor: (@value, @label, @shape) ->
    
  render: (ctx) ->
    super ctx
    ctx.save()
    ctx.translate(@x, @y)
    setStyle(ctx, node_text_style)
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'

    if @label.length > 0
      ctx.fillText(@label,0,2*@radius)

    ctx.fillText(@value, 0, 0)
    ctx.restore()

class Inner extends Node
  constructor: (@value, @child0, @child1, @shape) ->

  render: (ctx) ->
    ctx.save()
    setStyle(ctx, link_style)
    ctx.beginPath()
    ctx.moveTo(@x, @y)
    ctx.lineTo(@child0.x, @child0.y)
    ctx.moveTo(@x, @y)
    ctx.lineTo(@child1.x, @child1.y)
    ctx.stroke()
    ctx.restore()

    super ctx

    ctx.save()
    ctx.translate(@x, @y)
    setStyle(ctx, node_text_style)
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'

    ctx.fillText(@value, 0, 0)
    ctx.restore()
 
    @child0.render(ctx)
    @child1.render(ctx)

  forAll: (fn) ->
    @child0.forAll(fn)
    @child1.forAll(fn)
    fn(this)

  tryAll: (fn) ->
    result = @child0.tryAll(fn)
    if result?
      return result

    result = @child1.tryAll(fn)
    if result?
      return result

    fn(this)

class NodeCollection
  constructor: (@shape) ->
    @nodes = []

  addLeaves: (dict, pos) ->
    length = 0
    for value of dict
      length += 1

    i = 0
    for label, value of dict
      leaf = new Leaf(value, label, @shape)
      @nodes.push(leaf)
      leaf.x = pos.x + (i / length - .5 ) * 3 * leaf.radius * length
      leaf.y = pos.y

      i += 1

  render: (ctx, idx) ->
    if @merging?
      ctx.save()
      setStyle(ctx, light_link_style)
      ctx.beginPath()
      ctx.moveTo(@merging.node.x, @merging.node.y)
      ctx.lineTo(@merging.x, @merging.y)
      ctx.stroke()
      ctx.restore()

    for n in @nodes
      ctx.save()
      n.render(ctx)
      ctx.restore()

    ctx.save()
    ctx.translate(default_node_radius*2, default_node_radius*(2 + 3 * idx))
    setStyle(ctx, node_style)
    ctx.beginPath()
    renderShape(ctx, @shape, default_node_radius)
    ctx.stroke()
    ctx.restore()

  mousedown: (pos) ->
    for n in @nodes
      if n.isHit(pos)
        if @merging?
          if n isnt @merging.node
            @mergeNodes(@merging.node, n)
            @merging = null

            return true

    if @merging?
      @merging = null

    # try moving nodes
    for n in @nodes
      hit = n.tryAll( (node) ->
        if node.isHit(pos)
          node
        else
          null
      )

      if hit?
        @selected =
          node: hit
          ox: hit.x # original location
          oy: hit.y
          mx: pos.x # mousedown location
          my: pos.y
          t: Date.now()
        return true

    return false

  mousemove: (pos) ->
    if @selected?
      s = @selected
      dx = (pos.x - s.mx + s.ox) - s.node.x
      dy = (pos.y - s.my + s.oy) - s.node.y

      moveFn = (node) ->
        node.x += dx
        node.y += dy
      if s.node.forAll?
        s.node.forAll(moveFn)
      else
        moveFn(s.node)

    if @merging?
      @merging.x = pos.x
      @merging.y = pos.y

  mouseup: (pos) ->
    if @selected?
      if Date.now() - @selected.t < 200
        mdx = pos.x - @selected.mx
        mdy = pos.y - @selected.my
        if mdx*mdx+mdy*mdy < 10*10
          # call it a click

          if @selected.node in @nodes
            @merging =
              node: @selected.node
              x: pos.x
              y: pos.y

    @selected = null

  mergeNodes: (node0, node1) ->
    # filter both out of the list
    @nodes = ( n for n in @nodes when n isnt node0 and n isnt node1 )
    newnode = new Inner(node0.value + node1.value, node0, node1, @shape)
    newnode.x = (node0.x + node1.x) / 2
    newnode.y = Math.min(node0.y, node1.y) - Math.abs(node0.x - node1.x)
    @nodes.push(newnode)

# render loop
canvas = document.getElementById('cnv')
context = canvas.getContext('2d')

render = ->
  context.fillStyle = 'black'
  context.fillRect(0,0, canvas.width,canvas.height)

  if pendingString.length > 0
    context.fillStyle = 'white'
    context.font = '32px monospace'
    context.fillText(pendingString, 0, canvas.height - 32)

  for collection, idx in collections
    collection.render(context, idx)

  window.requestAnimationFrame(render)

window.requestAnimationFrame(render)

# input from user
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

canvas.addEventListener 'mousedown', (e) ->
  pos = getCursorPosition(canvas, e)
  for i in [collections.length - 1..0] by -1
    if collections[i].mousedown(pos)
      break

canvas.addEventListener 'mousemove', (e) ->
  pos = getCursorPosition(canvas, e)
  for collection in collections
    collection.mousemove(pos)

canvas.addEventListener 'mouseup', (e) ->
  pos = getCursorPosition(canvas, e)
  for collection in collections
    collection.mouseup(pos)
