collections = []
shapes = ['circle','square','hex']
next_shape = 0
construct_queue = []

nextPos = () ->
  x: canvas.width/2,
  y: canvas.height/2 + collections.length * default_node_radius * 4

# process keyboard input
pendingString = ''

engage = (str) ->
  if str.length == 0
    return
  
  direct_message = false

  pos = nextPos()

  if str[0] == ':'
    # making a CodeListCollection for letter->code pairs

    code_pairs = str[1..].split(',')
    codes = {}
    for pair in code_pairs
      [symbol, code] = pair.split('=')
      codes[symbol] = code

    if collections.length < 1 or
       not (collections[collections.length-1] instanceof CodeListCollection)
      collection = new CodeListCollection('diamond')
      collections.push(collection)
    else
      collection = collections[collections.length-1]
      pos.y -= default_node_radius * 4

    collection.addCodes(codes, pos)
  else
    # making a WeightedNodeCollection for a group of letters

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

    collection = new WeightedNodeCollection(shapes[next_shape])
    next_shape = (next_shape + 1) % shapes.length
    collection.addLeaves( letters, pos )
    collections.push(collection)

  return

#
node_style = stroke: 'white', width: 1.5, fill: 'black'
node_emph_style = stroke: 'white', width: 5.5, fill: 'black'
link_style = stroke: 'white', width: 1.5
light_link_style = stroke: 'white', width: .5
node_text_style = fill: 'white', font: '16px monospace'
node_text_error_style = fill: 'red', font: '16px monospace'
node_text_spacing = 18
menu_text_style = fill: 'white', font: '16px sans'
menu_text_invert_style = fill: 'black', font: '16px sans'
menu_text_spacing = 18

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
    when 'hex'
      ctx.moveTo(-radius,0)
      ctx.lineTo(-radius/2,-radius)
      ctx.lineTo(+radius/2,-radius)
      ctx.lineTo(+radius,0)
      ctx.lineTo(+radius/2,+radius)
      ctx.lineTo(-radius/2,+radius)
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

    if @value? && ((@value.length? && @value.length > 0) || @value > 0)
      ctx.fillText(@value, 0, 0)

      if @label? && @label.length > 0
        ctx.fillText(@label, 0, 2*@radius)
    else if @label? && @label.length >0
      ctx.fillText(@label, 0, 0)

    ctx.restore()

class Inner extends Node
  constructor: (@value, @child0, @child1, @shape) ->

  render: (ctx) ->
    ctx.save()
    setStyle(ctx, link_style)
    ctx.beginPath()
    if @child0?
      ctx.moveTo(@x, @y)
      ctx.lineTo(@child0.x, @child0.y)
    if @child1?
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

    if @value?
      ctx.fillText(@value, 0, 0)
    ctx.restore()
 
    if @child0?
      @child0.render(ctx)
    if @child1?
      @child1.render(ctx)

  forAll: (fn) ->
    if @child0?
      @child0.forAll(fn)
    if @child1?
      @child1.forAll(fn)
    fn(this)

  tryAll: (fn) ->
    if @child0
      result = @child0.tryAll(fn)
      if result?
        return result

    if @child1
      result = @child1.tryAll(fn)
      if result?
        return result

    fn(this)

class ShannonFanoNode extends Node
  constructor: (@contains, @shape, @default_bbox, @label) ->
    @len_x = @default_bbox.len.x
    @len_y = @default_bbox.len.y
    @x = @default_bbox.min.x + @len_x/2
    @y = @default_bbox.min.y + @len_y/2

    @update()

  render: (ctx) ->

    ctx.save()
    setStyle(ctx, node_style)
    ctx.translate(@x, @y)

    ctx.save()
    ctx.scale(@len_x,@len_y)
    ctx.beginPath()
    renderShape(ctx, @shape, .5)
    # fix line width
    ctx.scale(1/@len_x, 1/@len_y)
    ctx.fill()
    ctx.stroke()
    ctx.restore()

    setStyle(ctx, node_text_style)
    ctx.textAlign = 'center'
    ctx.textBaseline = 'bottom'

    ctx.fillText(@value, 0, -@len_y/2)

    ctx.restore()

    for n in @contains
      n.render(ctx)

  update: ->
    @value = 0

    if @contains.length > 0
      minx = maxx = @contains[0].x
      miny = maxy = @contains[0].y
      @value = @contains[0].value

      for n in @contains[1..]
        @value += n.value

        minx = Math.min(minx, n.x)
        maxx = Math.max(maxx, n.x)
        miny = Math.min(miny, n.y)
        maxy = Math.max(maxy, n.y)

      @x = (maxx+minx)/2
      @y = (maxy+miny)/2
      @len_x = maxx-minx+default_node_radius*6
      @len_y = maxy-miny+default_node_radius*6
    else
      @len_x = @default_bbox.len.x
      @len_y = @default_bbox.len.y

  getSize: () ->
    return width: @len_x, height: @len_y

  addNode: (node) ->
    @contains.push(node)
    node.parent = this
    @update()

  removeNode: (remove_node) ->
    @contains = (n for n in @contains when n isnt remove_node)
    remove_node.parent = null
    @update()

  isHit: (pos) ->
    (@x - pos.x <= @len_x/2 && pos.x - @x < @len_x/2) and
    (@y - pos.y <= @len_y/2 && pos.y - @y < @len_y/2)

  forAll: (fn) ->
    for n in @contains
      n.forAll(fn)
    fn(this)

  tryAll: (fn) ->
    for n in @contains
      result = n.tryAll(fn)
      if result?
        return result

    fn(this)

class CodeNode extends Node
  constructor: (@symbol, @code) ->
    @error = null
    @width = @radius

  render: (ctx) ->
    ctx.save()
    if @error?
      setStyle(ctx, node_text_error_style)
    else
      setStyle(ctx, node_text_style)
    ctx.textAlign = 'left'
    ctx.textBaseline = 'top'
    msg = "#{@symbol} = #{@code}"
    ctx.fillText(msg, @x, @y)
    @width = ctx.measureText(msg).width
    ctx.restore()

  isHit: (pos) ->
    dx = pos.x - @x
    dy = pos.y - @y
    
    dy > 0 && dy < node_text_spacing && dx > 0 && dx < @width

tidy_menu_item =
  name: 'tidy',
  action: (c, t) ->
    console.log('tidy trees')
    for n in c.nodes
      c.tidy(n, (x: n.x, y: n.y))

code_table_menu_item =
  name: 'convert to code table'
  action: (c, t) ->
    console.log('convert to code table')
    if c.nodes.length != 1
      console.log('only can convert a single tree')
    else
      c.convertToCode()

delete_menu_item =
  name: 'delete'
  action: (c, t) ->
    console.log('delete')
    c.delete_flag = true

sort_menu_item =
  name: 'sort by weight',
  action: (c, t) ->
    console.log('sort by weight')
    c.addAnimations(c.sortNodes( ((n1, n2) -> n2.value - n1.value), t))

collection_dropdown_menu = [
  tidy_menu_item,
  code_table_menu_item,
  delete_menu_item,
]

weighted_collection_dropdown_menu = [
  tidy_menu_item,
  code_table_menu_item,
  {
    name: 'Shannon-Fano',
    action: (c, t) ->
      console.log('Shannon-Fano')
      c.reconstruct_as = ShannonFanoNodeCollection
  },
  {
    name: 'Huffman',
    action: (c, t) ->
      console.log('Huffman')
      c.reconstruct_as = HuffmanNodeCollection
  },
  {
    name: 'average message size'
    action: (c, t) ->
      console.log('compute average message size')
      #c.averageSize()
  },
  {
    name: 'remove values'
    action: (c, t) ->
      console.log('remove values')
      c.reconstruct_as = NodeCollection
  },
  delete_menu_item,
]

huffman_collection_dropdown_menu = [
  sort_menu_item,
  tidy_menu_item,
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
      c.reconstruct_as = WeightedNodeCollection
  },
  delete_menu_item,
]

shannon_fano_dropdown_menu = [
  tidy_menu_item,
  {
    name: 'automatic Shannon-Fano step',
    action: (c, t) ->
      console.log('automatic Shannon-Fano step')
  },
  {
    name: 'finish Shannon-Fano',
    action: (c, t) ->
      console.log('finish Shannon-Fano')

      checkCompletion = (node) ->
        if node.contains? and node.contains.length != 1
          return false

        result = true
        if node.child0?
          result = result and
                   checkCompletion(node.child0) and checkCompletion(node.child1)
        return result

      if checkCompletion(c.nodes[0])
        c.reconstruct_as = WeightedNodeCollectionFromSF
      else
        console.log('won\'t finish S-F, incomplete')
  },
  delete_menu_item,
]

code_list_dropdown_menu = [
  {
    name: 'convert to tree',
    action: (c, t) ->
      console.log('convert to tree')
      c.convertToTree()
  },
  delete_menu_item,
]

class NodeCollection
  constructor: (@shape) ->
    @nodes = []
    @animations = []

  takeNodesFrom: (nc) ->
    @nodes = nc.nodes

    rvFn = (node) ->
      if node.value?
        node.saved_value = node.value
      delete node.value

    for n in @nodes
      n.forAll(rvFn)

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
          @dropdown_menu.pos.y + menu_text_spacing * (i+1),
          measure.width,
          menu_text_spacing)

        setStyle(ctx, if @dropdown_menu.selected == i
            menu_text_invert_style
          else
            menu_text_style)

        ctx.fillText(option.name,
          @dropdown_menu.pos.x,
          @dropdown_menu.pos.y + menu_text_spacing * (i+1))

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
           pos.y >= @dropdown_menu.pos.y + menu_text_spacing * (i+1) and
           pos.y <  @dropdown_menu.pos.y + menu_text_spacing * (i+2)
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

      if @delete_flag
        return null
      else if @reconstruct_as?
        newcollection = new @reconstruct_as(this.shape)
        newcollection.takeNodesFrom(this)
        delete @reconstruct_as
        return newcollection
      else
        return this

    if @selected?
      if t - @selected.t < .2
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

  addAnimations: (anims) ->
    @animations = @animations.concat(anims)

  tidy: (tree, tree_pos) ->
    rel_pos = []

    calcBounds = (node) ->
      if node.getSize?
        {width: own_width, height: own_height} = node.getSize()
      else
        own_width = node.radius * 2
        own_height = node.radius * 2
      width = own_width
      height = own_height

      children = []

      if node.child0?
        children.push(node.child0)
      else if node.child1?
        children.push((radius: default_node_radius, dummy: true))

      if node.child1?
        children.push(node.child1)
      else if node.child0?
        children.push((radius: default_node_radius, dummy: true))

      if children.length > 0
        children_width = 0
        children_max_height = 0
        for c, idx in children
          cb = calcBounds(c)

          children_width += cb.width
          children_max_height = Math.max(children_max_height, cb.height)

        width = Math.max(own_width, children_width)
        height = Math.max(own_height,
          children_max_height + 2 * default_node_radius)

        x = -width/2

        for c, idx in children
          rel_pos.push (
            parent: node
            child: c
            pos: ( x: x + width / children.length / 2, y:
                      default_node_radius * 3 )
          )
          x += width / children.length

      width: width + default_node_radius
      height: height + default_node_radius

    calcBounds(tree)

    duration = .1
    anims = [ new NodeAnimation(tree, tree_pos, duration) ]

    # rel_pos forms a post-order traversal, so by taking it backwards
    # we will always have the new position for the root computed before we
    # visit its children
    moved_nodes = [tree]
    new_positions = [tree_pos]

    for i in [rel_pos.length-1 ..0] by -1
      rp = rel_pos[i]
      c = rp.child
      p = rp.parent
      pos = rp.pos

      if c.dummy
        continue

      pidx = moved_nodes.indexOf(p)
      ppos = new_positions[pidx]

      if c.getSize?
        {height: own_height} = c.getSize()
      else
        own_height = c.radius * 2

      newpos = (x: ppos.x + pos.x, y: ppos.y + pos.y + own_height/2)
      new_positions.push(newpos)
      moved_nodes.push(c)

      anims.push(new NodeAnimation(c, newpos, duration))

    @addAnimations([new CollectionAnimation(anims, -1)])

  convertToCode: () ->
    codes = {}
    walkTree = (node, base = '') ->
      if node.child0?
        walkTree(node.child0, base+'0')
      if node.child1?
        walkTree(node.child1, base+'1')

      if node.label? && node.label.length > 0
        codes[node.label] = base
    
    walkTree(@nodes[0])

    construct_queue.push((const: CodeListCollection, add_from: codes))

class WeightedNodeCollection extends NodeCollection
  constructor: (shape) ->
    super shape

  takeNodesFrom: (nc) ->
    # override basic NodeCollection takeNodesFrom that strips weights
    @nodes = nc.nodes

  collection_dropdown_menu: weighted_collection_dropdown_menu

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

  sortNodes: (compare, t) ->
    if @nodes.length == 1
      return []

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

    return anims

class HuffmanNodeCollection extends WeightedNodeCollection
  constructor: (shape) ->
    super shape

  mousedown: (pos, idx, t) ->
    if @merging?
      for n in @nodes
        if n.isHit(pos)
          if n isnt @merging.node
            if @merging.node.x < n.x
              @mergeNodes(@merging.node, n)
              @merging = null
              return true
            else
              console.log('abort merge from right to left')

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
    

class ShannonFanoNodeCollection extends WeightedNodeCollection
  constructor: (shape) ->
    super shape

  defaultBBoxAt: (pos) ->
    min: (x: pos.x - default_node_radius*2, y: pos.y - default_node_radius*2)
    len: (x: default_node_radius*4, y: default_node_radius*2)

  takeNodesFrom: (nc) ->
    anims = nc.sortNodes( ((n1, n2) -> n2.value - n1.value), 1)
    @addAnimations(anims)
    @nodes = [
      new ShannonFanoNode(nc.nodes, @shape, @defaultBBoxAt((x:100,y:100)), "") ]

  render: (ctx, idx, t) ->
    if @splitting?
      ctx.save()
      setStyle(ctx, light_link_style)
      ctx.beginPath()
      ctx.moveTo(@splitting.node.x, @splitting.node.y)
      ctx.lineTo(@splitting.pos0.x, @splitting.pos0.y)
      ctx.moveTo(@splitting.node.x, @splitting.node.y)
      ctx.lineTo(@splitting.pos1.x, @splitting.pos1.y)

      ctx.stroke()
      ctx.restore()

    super ctx, idx, t

  collection_dropdown_menu: shannon_fano_dropdown_menu

  mousedown: (pos, idx, t) ->
    if super(pos, idx, t)
      return true

    if @splitting?
      @splitNode(@splitting.node, @splitting.pos0, @splitting.pos1)
      @splitting = null
      return true

  mousemove: (pos) ->
    super pos

    if @splitting?
      @splitting.pos0 = (x: pos.x, y: pos.y)
      @splitting.pos1 = (x: 2*@splitting.node.x - pos.x, y: pos.y)

    return

  mouseup: (pos, t) ->
    if @selected? and @selected.node.parent? and
       not @selected.node.parent.isHit(pos)
      # move into the sibling
      this_node = @selected.node.parent
      other_node = this_node.sibling
      this_node.removeNode(@selected.node)
      other_node.addNode(@selected.node)

    return_value = super(pos,t)
    
    updateFn = (node) ->
      if node.update?
        node.update()
    
    for n in @nodes
      n.forAll(updateFn)

    return return_value

  clickend: (pos, t) ->
    if @splitting
      @splitting = null
    else if @selected.node.contains? and @selected.node.contains.length > 1
      @splitting = node: @selected.node, pos0: pos, pos1: pos

  splitNode: (node, pos0, pos1) ->
    new0 = new ShannonFanoNode(node.contains, @shape, @defaultBBoxAt(pos0), 0)
    new1 = new ShannonFanoNode([], @shape, @defaultBBoxAt(pos1), 1)
    new0.sibling = new1
    new1.sibling = new0

    for n in node.contains
      n.parent = new0

    newnode = new Inner(node.value, new0, new1, @shape)

    new1.move(node.x, node.y)
    @addAnimations([@makeMoveContainsAnim([new0,new1], [pos0,pos1], .2, -1)])

    newnode.x = node.x
    newnode.y = node.y

    @replaceNode(node, newnode)

  replaceNode: (oldnode, newnode) ->
    # replace in any inner node
    replaceFn = (node) ->
      if node.child0 == oldnode
        node.child0 = newnode
      if node.child1 == oldnode
        node.child1 = newnode

    for n in @nodes
      n.forAll(replaceFn)

    # replace a root
    @nodes = for n in @nodes
      if n is oldnode
        newnode
      else
        n

    return

  makeMoveContainsAnim: (nodes, dests, duration, t) ->
    anims = []

    for node, idx in nodes
      dest = dests[idx]
      dx = dest.x - node.x
      dy = dest.y - node.y

      anims.push( new NodeAnimation(node, dest, duration) )

      for n in node.contains
        anims.push(new NodeAnimation(n, (x: n.x + dx, y: n.y + dy), duration))

    return new CollectionAnimation(anims, t)
 
class WeightedNodeCollectionFromSF extends WeightedNodeCollection
  constructor:  (shape) ->
    super (shape)
  takeNodesFrom: (sf) ->
    rebuildFromSF = (node) =>
      if node.contains?
        nold = node.contains[0]
        n = new Leaf(nold.value, nold.label, @shape)
      else if node.child0?
        n = new Inner(node.value,
          rebuildFromSF(node.child0),
          rebuildFromSF(node.child1),
          @shape)
      else
        throw 'hit unhandled node'
        return null

      n.x = node.x
      n.y = node.y

      return n
    @nodes = [rebuildFromSF(sf.nodes[0])]

class CodeListCollection extends NodeCollection
  constructor: (shape) ->
    super shape
    @codes = {}
    @errors = false

  collection_dropdown_menu: code_list_dropdown_menu

  addCodes: (codes, pos) ->
    for symbol, code of codes
      @addCode(symbol, code)

    @arrangeCodes(pos.x, pos.y)

  setNodes: (codes, pos) -> @addCodes(codes, pos)

  addCode: (symbol, code) ->
    oldval = @codes[symbol]
    newval = new CodeNode(symbol, code)

    if oldval?
      # replace it
      @nodes = (
        for n in @nodes
          if n == oldval
            newval
          else
            n
      )
    else
      # append it
      @nodes.push(newval)

    @codes[symbol] = newval

    @checkForErrors()

  checkForErrors: () ->
    @errors = false

    for n in @nodes
      n.error = null

    for symbol, codeobj of @codes
      ok = true

      for symbol2, codeobj2 of @codes
        if symbol == symbol2
          continue
        if codeobj2.code.indexOf(codeobj.code) == 0
          ok = false
          @errors = true
          # codeobj appears in codeobj2
          err = (start: 0, end: codeobj.code.length)
          if codeobj2.error?
            codeobj2.error.push(err)
          else
            codeobj2.error = [err]
      if not ok
        codeobj.error = [(start: 0, end: codeobj.code.length)]

    return @errors

  arrangeCodes: (start_x, start_y) ->
    y = start_y
    for symbol, codeobj of @codes
      codeobj.x = start_x
      codeobj.y = y
      y += node_text_spacing

  mousemove: (pos) ->
    if @selected? and @selected.node in @nodes
      s = @selected
      dx = pos.x - s.mx + s.ox - s.node.x
      dy = pos.y - s.my + s.oy - s.node.y

      for n in @nodes
        n.x += dx
        n.y += dy
    else
      super pos


  convertToTree: () ->
    if @checkForErrors()
      throw 'not going to convert with errors'

    root = {}
    for symbol, codeobj of @codes
      c = codeobj.code
      curnode = root
      for i in [0...c.length]
        ci = c[i]
        if ci == '0'
          childstr = 'child0'
        else if ci == '1'
          childstr = 'child1'
        else
          throw 'bad character ' + ci

        if curnode[childstr]?
          curnode = curnode[childstr]
        else
          curnode = curnode[childstr] = {}

      curnode.leaf = symbol

    construct_queue.push((const: NodeCollectionFromCode, add_from: root))

class NodeCollectionFromCode extends NodeCollection
  constructor:  (shape) ->
    super (shape)
  setNodes: (tree, pos) ->
    rebuildFromTree = (node) =>
      if node.leaf?
        newnode = new Leaf('',node.leaf,@shape)
      else
        if node.child0?
          newchild0 = rebuildFromTree(node.child0)
        else
          newchild0 = null
        if node.child1?
          newchild1 = rebuildFromTree(node.child1)
        else
          newchild1 = null

        newnode = new Inner('', newchild0, newchild1, @shape)

      newnode.x = pos.x
      newnode.y = pos.y
      return newnode

    @nodes = [rebuildFromTree(tree)]
    @tidy(@nodes[0], pos)

    return


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

  # process collections, possibly replacing with conversions
  collections = (c.mouseup(pos, t) for c in collections)
  
  # filter out deleted (null) collections
  collections = (c for c in collections when c isnt null)

  # construct new collections
  while construct_queue.length > 0
    c = construct_queue.shift()
    collection = new c.const(shapes[next_shape])
    next_shape = (next_shape + 1) % shapes.length
    collection.setNodes(c.add_from, nextPos())
    collections.push(collection)

  # TODO: Each of these has subtly different semantics, and within the
  # conversion mechanism there are a few variants as well, this should be2
  # handled more cleanly
