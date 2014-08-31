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
  collection.addLeaves(
    letters,
    (x: canvas.width/2, y: canvas.height/2 +
                           collections.length * default_node_radius * 4)
  )
  collections.push(collection)

  return

#
node_style = stroke: 'white', width: 1.5, fill: 'black'
node_emph_style = stroke: 'white', width: 5.5, fill: 'black'
link_style = stroke: 'white', width: 1.5
light_link_style = stroke: 'white', width: .5
node_text_style = fill: 'white', font: '16px monospace'
menu_text_style = fill: 'white', font: '16px sans'
menu_text_invert_style = fill: 'black', font: '16px sans'
menu_text_height = 18

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

  move: (newx, newy) ->
    # move a node and its children
    dx = newx - @x
    dy = newy - @y

    moveFn = (node) ->
      node.x += dx
      node.y += dy
    @forAll(moveFn)

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

collection_dropdown_menu = [
  {
    name: 'sort by weight',
    action: (c, t) ->
      console.log('sort by weight')
      c.sortNodes( ((n1, n2) -> n2.value - n1.value), t)
  },
  {
    name: 'Shannon-Fano',
    action: (c, t) ->
      console.log('Shannon-Fano')
  },
  {
    name: 'Huffman',
    action: (c, t) ->
      console.log('Huffman')
      c.reconstruct_as = HuffmanNodeCollection
  }
]

huffman_collection_dropdown_menu = [
  {
    name: 'sort by weight',
    action: (c, t) ->
      console.log('sort by weight')
      c.sortNodes( ((n1, n2) -> n2.value - n1.value), t)
  },
  {
    name: 'automatic Huffman step',
    action: (c, t) ->
      console.log('automatic Huffman step')
  },
  {
    name: 'finish Huffman'
    action: (c, t) ->
      console.log('finish Huffman')
      # TODO: maybe first this should automatically finish the construction?
      c.reconstruct_as = NodeCollection
  }
]

shannon_fano_dropdown_menu = [
  {
    name: 'sort by weight',
    action: (c, t) ->
      console.log('sort by weight')
      c.sortNodes( ((n1, n2) -> n2.value - n1.value), t)
  },
  {
    name: 'sort alpha',
    action: (c, t) ->
      console.log('sort alpha')
  },
  {
    name: 'automatic Shannon-Fano step',
    action: (c, t) ->
      console.log('automatic Shannon-Fano step')
  },
  {
    name: 'finish Shannon-Fano',
    action: (c, t) ->
      console.log('finish Shannon-Fano')
  }
]

class NodeCollection
  constructor: (@shape) ->
    @nodes = []
    @animations = []

  copyNodesFrom: (nc) ->
    @nodes = nc.nodes

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

  render: (ctx, idx, t) ->
    if @animations.length > 0
      @animations[0].setPositions(t)
      if @animations[0].isFinished(t)
        @animations = @animations[1..]

    for n in @nodes
      ctx.save()
      n.render(ctx)
      ctx.restore()

    ctx.save()
    ctx.translate(default_node_radius*2, default_node_radius*(2 + 3 * idx))
    setStyle(ctx, node_style)
    ctx.beginPath()
    renderShape(ctx, @shape, default_node_radius)

    if @dropdown_menu?
      ctx.fillStyle = ctx.strokeStyle
      ctx.fill()
    else
      ctx.stroke()

    ctx.restore()

    return

  render_overlay: (ctx, idx) ->
    if @dropdown_menu?
      ctx.save()
      ctx.textAlign = 'start'
      ctx.textBaseline = 'top'

      for option, i in @dropdown_menu.options
        setStyle(ctx, menu_text_style)
        measure = ctx.measureText(option.name)
        ctx.fillStyle= if @dropdown_menu.selected == i then 'white' else 'black'
        ctx.fillRect(
          @dropdown_menu.pos.x,
          @dropdown_menu.pos.y + menu_text_height * (i+1),
          measure.width,
          menu_text_height)

        setStyle(ctx, if @dropdown_menu.selected == i
            menu_text_invert_style
          else
            menu_text_style)

        ctx.fillText(option.name,
          @dropdown_menu.pos.x,
          @dropdown_menu.pos.y + menu_text_height * (i+1))

      ctx.restore()
    return


  mousedown: (pos, idx, t) ->
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
          t: t
        return true

    if @isHandleHit(pos, idx)
      @dropdown_menu = {
        pos: pos
        options: @collection_dropdown_menu
        selected: -1
      }
    return false

  isHandleHit: (pos, idx) ->
    dx = pos.x - default_node_radius*2
    dy = pos.y - default_node_radius*(2 + 3 * idx)

    return dx*dx + dy*dy < default_node_radius*default_node_radius

  collection_dropdown_menu: collection_dropdown_menu

  mousemove: (pos) ->
    if @dropdown_menu?
      @dropdown_menu.selected = -1
      for option, i in @dropdown_menu.options
        if pos.x > @dropdown_menu.pos.x and
           pos.y >= @dropdown_menu.pos.y + menu_text_height * (i+1) and
           pos.y <  @dropdown_menu.pos.y + menu_text_height * (i+2)
          @dropdown_menu.selected = i
      return

    if @selected?
      s = @selected
      newx = pos.x - s.mx + s.ox
      newy = pos.y - s.my + s.oy

      s.node.move(newx, newy)

    return

  # may return a new replacement object, otherwise returns same object
  mouseup: (pos, t) ->
    if @dropdown_menu?
      if @dropdown_menu.selected >= 0
        @dropdown_menu.options[@dropdown_menu.selected].action(this, t)
      @dropdown_menu = null

      if @reconstruct_as?
        newcollection = new @reconstruct_as(this.shape)
        newcollection.copyNodesFrom(this)
        delete @reconstructas
        return newcollection
      else
        return this

    if @selected?
      if t - @selected.t < 200
        mdx = pos.x - @selected.mx
        mdy = pos.y - @selected.my
        if mdx*mdx+mdy*mdy < 10*10
          # call it a click

          @clickend(pos, t)
    @selected = null

    return this

  clickend: ->

  makeLineupAnim: (yoffset, duration, t) ->
    midpointy = 0
    for n in @nodes
      midpointy += n.y
    midpointy /= @nodes.length

    anims =
      (new NodeAnimation(n, (x:n.x, y:midpointy+yoffset), duration)) for n in @nodes

    return new CollectionAnimation(anims, t)

  makeMove1Anim: (node, dest, duration, t) ->
    return new CollectionAnimation([new NodeAnimation(node, dest, duration)], t)

  sortNodes: (compare, t) ->
    if @nodes.length == 1
      return

    anims = []
    anims.push(@makeLineupAnim(default_node_radius*2, .1, t))

    minx = @nodes[0].x
    maxx = @nodes[0].x
    totaly =  @nodes[0].y

    for n in @nodes[1..]
      totaly += n.y
      minx = Math.min(n.x, minx)
      maxx = Math.max(n.x, maxx)

    desty = totaly / @nodes.length
    width = Math.max(maxx - minx, @nodes.length * default_node_radius * 2)
    spacing = width / (@nodes.length-1)

    oldnodes = @nodes.slice(0) # clone
    newnodes = []

    while oldnodes.length > 0
      max = oldnodes[0]
      maxi = 0
      for n,i in oldnodes[1..]
        if compare(n, max) > 0
          max = n
          maxi = i+1

      oldnodes = (n for n,i in oldnodes when i != maxi)
      anims.push(@makeMove1Anim(max,
        (x: minx+newnodes.length*spacing, y: desty), .1, -1))
      newnodes.push(max)

    @nodes = newnodes

    @animations = @animations.concat(anims)

    return


class HuffmanNodeCollection extends NodeCollection
  constructor: (shape) ->
    super shape

  copyNodesFrom: (nc) ->
    @nodes = nc.nodes

  mousedown: (pos, idx, t) ->
    for n in @nodes
      if n.isHit(pos)
        if @merging?
          if n isnt @merging.node
            @mergeNodes(@merging.node, n)
            @merging = null

            return true

    if @merging?
      @merging = null

    super pos, idx, t

  mousemove: (pos) ->
    super pos

    if @merging?
      @merging.x = pos.x
      @merging.y = pos.y
    return

  collection_dropdown_menu: huffman_collection_dropdown_menu

  mergeNodes: (node0, node1) ->
    # filter both out of the list
    @nodes = ( n for n in @nodes when n isnt node0 and n isnt node1 )
    newnode = new Inner(node0.value + node1.value, node0, node1, @shape)
    newnode.x = (node0.x + node1.x) / 2
    newnode.y = Math.min(node0.y, node1.y) - Math.abs(node0.x - node1.x)
    @nodes.push(newnode)

  clickend: (pos, t) ->
    if @selected.node in @nodes
      @merging =
        node: @selected.node
        x: pos.x
        y: pos.y
    else
      super pos, t

  render: (ctx, idx, t) ->
    if @merging?
      ctx.save()
      setStyle(ctx, light_link_style)
      ctx.beginPath()
      ctx.moveTo(@merging.node.x, @merging.node.y)
      ctx.lineTo(@merging.x, @merging.y)
      ctx.stroke()
      ctx.restore()

    super ctx, idx, t
    

class ShannonFanoNodeCollection extends NodeCollection


lerp2d = (t, p0, p1) ->
  if t < 0
    t = 0
  if t > 1
    t = 1
  x: (p1.x - p0.x)*t + p0.x
  y: (p1.y - p0.y)*t + p0.y

class NodeAnimation
  constructor: (@node, @destpos, @duration) ->
    @origpos = null

  setPosition: (time) ->
    if @origpos == null
      @origpos = {x: @node.x, y: @node.y}

    pos = lerp2d(time/@duration, @origpos, @destpos)
    @node.move(pos.x, pos.y)

  isFinished: (time) ->
    time >= @duration

class CollectionAnimation
  constructor: (@node_animations, @start_time) ->

  setPositions: (time) ->
    if @start_time == -1
      @start_time = time
    for a in @node_animations
      a.setPosition(time - @start_time)

  isFinished: (time) ->
    for a in @node_animations
      if not a.isFinished(time - @start_time)
        return false
    return true

# render loop
canvas = document.getElementById('cnv')
context = canvas.getContext('2d')

render = ->
  t = Date.now()/1000

  context.fillStyle = 'black'
  context.fillRect(0,0, canvas.width,canvas.height)

  if pendingString.length > 0
    context.fillStyle = 'white'
    context.font = '32px monospace'
    context.fillText(pendingString, 0, canvas.height - 32)

  for collection, idx in collections
    collection.render(context, idx, t)

  for collection, idx in collections
    collection.render_overlay(context, idx, t)

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
  t = Date.now()/1000
  pos = getCursorPosition(canvas, e)
  for idx in [collections.length - 1..0] by -1
    if collections[idx].mousedown(pos, idx, t)
      break

canvas.addEventListener 'mousemove', (e) ->
  pos = getCursorPosition(canvas, e)
  for collection in collections
    collection.mousemove(pos)

canvas.addEventListener 'mouseup', (e) ->
  t = Date.now()/1000
  pos = getCursorPosition(canvas, e)
  collections = (collection.mouseup(pos, t) for collection in collections)
