module.exports =
  pkg:
    name: 'bar', version: '0.0.1'
    extend: {name: "@makechart/base"}
    dependencies: []
    i18n:
      "zh-TW":
        "size": "長度"
  init: ({root, context, t, pubsub}) ->
    pubsub.fire \init, mod: mod({context, t})

mod = ({context, t}) ->
  {chart,d3,debounce} = context
  sample: ->
    cat = <[apple banana peach orange]>
    raw: [0 to 10].map (val) ~>
      ret = {name: "Y#{1995 + val}"}
      for i from 0 to 3 => ret[cat[i]] = (10 * Math.random!).toFixed(1)
      return ret
    binding:
      size: [0 to 3].map (i) -> {key: cat[i], unit: "KG"}
      name: {key: "name"}
  config: {
    legend: {} <<< chart.utils.config.preset.legend
    xaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis))
    yaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis))
  } <<< chart.utils.config.preset.default <<<
    sort:
      enabled: type: \boolean, default: false
      dir: type: \choice, values: <[asc desc]>, default: \asc
      dimension: type: \choice, values: <[name size]>, default: \size
    type: type: \choice, values: <[bar column]>, default: \column
    brush:
      enabled: type: \boolean, default: true
    multiple: type: \choice, values: <[stack group]>, default: \stack
    percent: type: \boolean, default: false
    dancing: type: \boolean, default: true
    gap: type: \number, default: 2, min: 0, max: 100, step: 1
  dimension:
    size: {type: \R, multiple: true, name: "size"}
    name: {type: \NCO, name: "name"}
  init: ->
    @tint = tint = new chart.utils.tint!
    @svg.addEventListener \click, (e) ~>
      n = e.target
      while n != @svg
        if !n => return
        if !(n.classList and n.classList.contains(\pdl-cell)) =>
          n = n.parentNode
          continue
        if n.getAttribute(\data-name) == \view => break else return
      if !@cfg.dancing or @cfg.percent => return
      idx = @align-idx or 0
      while true
        @align-idx = ((@align-idx or 0) + 1) % (@binding.size.length + 1)
        if @legend.is-visible(@align-idx) or @align-idx == idx => break
      @resize!
      @render!
    @g = Object.fromEntries <[view xaxis yaxis legend]>.map ~> [it, d3.select(@layout.get-group it)]
    @g.subview = @g.view.append \g
    @g.brush = @g.view.append \g
    @brushs = x: d3.brushX!, y: d3.brushY!
    @brush-type = ~> if @cfg.type == \bar => \y else \x
    @range = "null"
    brush = debounce 150, (e) ~>
      if !@cfg.brush.enabled => return
      range = e.selection
      if (_range = JSON.stringify(range)) == @range => return else @range = _range
      if !range => @filter {name: undefined}, true
      else
        domain = @scale[@brush-type!]domain!
        bandwidth = @scale[@brush-type!]bandwidth!
        if @brush-type! == \x =>
          range = range.map -> Math.floor(it / bandwidth) >? 0 <? (domain.length - 1)
          ret = [range.0 to range.1].map -> domain[it]
        else
          box = @layout.get-box \view
          range = range.map -> Math.floor((box.height - it) / bandwidth) >? 0 <? (domain.length - 1)
          ret = [range.1 to range.0].map -> domain[it]
        @filter {name: {type: 'index', value: ret}}, true
    @brushs.x.on \end, (e) ~> if @brush-type! == \x => brush e
    @brushs.x.on \brush, (e) ~> if @brush-type! == \x => brush e
    @brushs.y.on \end, (e) ~> if @brush-type! == \y => brush e
    @brushs.y.on \brush, (e) ~> if @brush-type! == \y => brush e
    @scale = scale = {}
    @yaxis = new chart.utils.axis layout: @layout, name: \yaxis, direction: \left
    @xaxis = new chart.utils.axis layout: @layout, name: \xaxis, direction: \bottom
    @legend = new chart.utils.legend do
      layout: @layout
      name: \legend
      root: @root
      shape: (d) -> d3.select(@).attr \fill, tint.get(d.text or d.key)
    @legend.on \select, ~> @bind!; @resize!; @render!
    # d3.brush covers the whole svg element. need to support by calculation. TODO
    # for now we simply hide brush group if brush is not enabled
    @tip = new chart.utils.tip {
      root: @root
      accessor: ({evt}) ~>
        if !(evt.target and data = d3.select(evt.target).datum!) => return null
        # brush 蓋在整個繪圖區上, 開著的時候 hover 全部打在它身上, tip 就再也出不來.
        # 拿座標往下找真正被指到的那一根 - elementsFromPoint 回傳的是整疊命中的元素,
        # brush 自己的幾片在最上面, 底下才是 bar
        if data.type in <[overlay selection s]> and evt.client-x? =>
          data = null
          for n in document.elements-from-point(evt.client-x, evt.client-y)
            d = d3.select(n).datum!
            if !d or (d.type in <[overlay selection s]>) => continue
            if !(d.raw?) => continue
            data = d
            break
        if !data => return null
        if data.type in <[overlay selection s]> => return
        p = if !@cfg.percent => ""
        else if isNaN(data.percent) => "(-%)"
        else "(#{(data.percent * 100).toFixed(1)}%)"
        v = if isNaN(data.raw) => '-'
        else
          fmt = @cfg?[if @type == \column => \yaxis else \xaxis]?label?format or '.2s'
          "#{d3.format(fmt)(data.raw)}#{data.unit or ''}"
        return {name: data.name or '', group: data.group or '', value: v, value-alt: p}
      range: ~> @layout.get-node \view .getBoundingClientRect!
    }
    /* # this is a PoC of updating brush automatically
    setInterval (~>
      if @cfg.type == \column =>
        if !@scale?x => return
        w = @scale.x.bandwidth!
        range = @scale.x.range!
        @_x = (@_x or range.0)
        @g.brush.call @brushs.x.move, [@_x + w * 0.1, @_x + w * 0.8]
        @_x = @_x + w
        if @_x + w > range.1 => @_x = 0
    ), 1000 */

  destroy: -> if @tip => @tip.destroy!

  filter: (filters, internal = false) ->
    @render!
    # internal = 這個 filter 就是 brush 自己發出來的, 不必再回頭動 brush
    if internal => return
    if !@brush or !(node = @g.brush.node!) or !node.__brush => return
    f = (filters or {}).name
    # 舊寫法: 直接給 brush 的像素區間
    if Array.isArray f => return @brush.move @g.brush, f.map ~> @scale[@brush-type!](it)
    scale = @scale[@brush-type!]
    if !scale or !scale.domain => return
    vs = (f or {}).value or []
    domain = scale.domain!
    idx = (vs.map -> domain.indexOf it).filter -> it >= 0
    if !idx.length => return @brush.move @g.brush, null
    [a, b] = [Math.min.apply(Math, idx), Math.max.apply(Math, idx)]
    bw = scale.bandwidth!
    # 目前這個框已經框到同一批 band 就不要動它. host 每次 render 都會把選取灌回來,
    # 不擋的話使用者放開滑鼠就會看到框跳去對齊格線 - 選的東西沒變, 只是框自己動了
    if (cur = d3.brush-selection node) =>
      ci = if @brush-type! == \x => cur.map ~> Math.floor(it / bw) >? 0 <? (domain.length - 1)
      else
        box = @layout.get-box \view
        cur.map ~> Math.floor((box.height - it) / bw) >? 0 <? (domain.length - 1)
      if (Math.min.apply(Math, ci) == a and Math.max.apply(Math, ci) == b) => return
    # brush 只認得連續區間, 所以外面灌進來的值列表取頭尾.
    # 遠端那一側退 1px: 剛好落在格線上會被 Math.floor 算進下一格, 灌回去的選取
    # 就會每同步一次多吃一根 ( 來回幾次整排都被選中 )
    if @brush-type! == \x => @brush.move @g.brush, [a * bw, (b + 1) * bw - 1]
    else
      box = @layout.get-box \view
      @brush.move @g.brush, [box.height - (b + 1) * bw + 1, box.height - a * bw]
  parse: ->
    @data.map (d) -> d.size = d.size.map -> if isNaN(it) => 0 else it
    @align-idx = undefined
  resize: ->
    @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, @cfg.legend.position == \bottom
    @type = @cfg.type or \column
    @brush = @brushs[@brush-type!]
    @legend.config @cfg.legend
    # order reversed to make it visually aligned with bar.
    @legend.data [{
      key: i, text: @binding.size[i].name or @binding.size[i].key
    } for i from @binding.size.length - 1 to 0 by -1 ]
    @layout.update false

    #@tip.toggle(if @cfg.{}tip.enabled? => @cfg.tip.enabled else true)

    @max-per-group = @binding.size
      .filter (d,i) ~> @legend.is-visible(i)
      .map (d,i) ~> Math.max.apply(Math, @data.map -> it.size[i])

    # alternative align base. required for dancing stack
    if @cfg.align-idx and !@align-idx => @align-idx = @cfg.align-idx
    align-idx = (if @cfg.percent => 0 else (@align-idx or 0)) <? @binding.size.length
    @base-offset = @data.map (d) ~> [0 til align-idx].reduce(
      ((a,b) ~> a + if !@legend.is-visible b => 0 else d.size[b]),0
    ) or [0]
    @delta = delta = Math.max.apply(Math, @base-offset)
    # stack bar
    if @cfg.multiple == \stack
      # 100% stack
      if @cfg.percent => max = 1
      else
        max = Math.max.apply(Math,
          @data.map (d) ~> [align-idx til d.size.length].reduce(
            ((a,b) ~> a + if !@legend.is-visible b => 0 else d.size[b]),0
          )
        ) + (delta or 0)
    # group bar
    else if @cfg.multiple == \group
      max = Math.max.apply(
        Math,
        @data.map (d) ~> Math.max.apply(Math, d.size.filter((v,i)~>@legend.is-visible(i)))
      )
    # split bars
    else if @cfg.multiple == \split
      max = @max-per-group.reduce(((a,b) -> a + b),0)
    @order = @data.map (d,i) -> {key: d._idx, idx: i, name: d.name}
    @data.map (d,i) ~> d.sum = d.size.filter((d,i) ~> @legend.is-visible(i)).reduce(((a,b) -> a + b),0)
    if @cfg.{}sort.enabled =>
      @order.sort (a,b) ~>
        d = if @cfg.sort.dimension == \size => (@data[a.idx].sum - @data[b.idx].sum)
        else
          na = @data[a.idx].name
          nb = @data[b.idx].name
          na = if isNaN(+na) => na else +na
          nb = if isNaN(+nb) => nb else +nb
          if na > nb => 1 else if na < nb => -1 else 0
        (if @cfg.sort.dir == \asc xor @cfg.type == \bar => 1 else -1) * d
    if @cfg.palette => @tint.set @cfg.palette
    @layout.update false

    box = @layout.get-box \view

    if @type == \column =>
      @scale <<<
        y: d3.scaleLinear!domain([0,max]).range [box.height, 0]
        x: d3.scaleBand!domain @order.map(->it.name or it.key) .range [0, box.width]
      max-tick = Math.ceil(@layout.get-box \yaxis .height / 40) >? 2
      yticks = if @cfg.bump => [1 to ((@parsed.length or 1) >? 1)]
      else @scale.y.ticks((@cfg.{}yaxis.tick.count or 4) <? max-tick)
      @yaxis.config @cfg.yaxis
      v = @binding.size.0 or {}
      if @binding.size.length > 1 => @yaxis.caption( if v.unit => "#{v.unit}" else '')
      else @yaxis.caption( (v.name or v.key or '') + if v.unit => "(#{v.unit})" else '')
      @yaxis.ticks yticks
      @yaxis.scale @scale.y
      @xaxis.config @cfg.xaxis
      @xaxis.ticks @data.map -> it.name
      @xaxis.scale @scale.x
      @xaxis.caption(
        if @binding.name =>
          (that.name or that.key or '') + (if that.unit => "(#{@binding.name.unit})" else '')
        else ''
      )
    else
      @scale <<<
        x: d3.scaleLinear!domain([0,max]).range [box.width, 0]
        y: d3.scaleBand!domain @order.map(->it.name or it.key) .range [0, box.height]
      max-tick = Math.ceil(@layout.get-box \xaxis .width / 80) >? 2
      xticks = if @cfg.bump => [1 to ((@parsed.length or 1) >? 1)]
      else @scale.x.ticks((@cfg.{}xaxis.tick.count or 4) <? max-tick)
      @xaxis.config @cfg.xaxis
      v = @binding.size.0 or {}
      if @binding.size.length > 1 => @xaxis.caption( if v.unit => "#{v.unit}" else '')
      else @xaxis.caption( (v.name or v.key or '') + if v.unit => "(#{v.unit})" else '')
      @xaxis.ticks xticks
      @xaxis.scale @scale.x
      @yaxis.config @cfg.yaxis
      @yaxis.ticks @data.map -> it.name
      @yaxis.scale @scale.y
      @yaxis.caption(
        if @binding.name =>
          (that.name or that.key or '') + (if that.unit => "(#{@binding.name.unit})" else '')
        else ''
      )

    # xaxis and yaxis affect each other and they all affect view.
    # we may need to update them until stable but for now we simply layout twice.
    for i from 0 til 2 =>
      @layout.update false
      box = @layout.get-box('view')
      [w,h] = [box.width, box.height]
      @tint.set @cfg.palette
      r = @cfg.dot-size or 3
      @scale.x.range [0, w - r]
      @scale.y.range [h, r]
      @xaxis.render!
      @yaxis.render!

    box = @layout.get-box \view
    if @brush-type! == \x => @brush.extent [[0, 1],[box.width, box.height - 2]]
    else @brush.extent [[1, 0],[box.width - 2, box.height]]

  render: ->
    {binding, scale, range, delta, base-offset, max-per-group, cfg, tint, data, type, legend} = @
    self = @
    partial = (@subset.mode! == \partial)
    gap = @cfg.gap
    gap <?= (if @type == \column => scale.x.bandwidth! else scale.y.bandwidth!) - 1
    @g.subview.selectAll \g.bar .data @data
      ..exit!remove!
      ..enter!append \g .attr \class, \bar
        .attr \transform, (d,i) ~>
          if @type == \column => "translate(#{scale.x(d.name)},0)"
          else "translate(0,#{scale.y(d.name)})"
    @g.subview.selectAll \g.bar
      .transition!duration 350
      .attr \transform, (d,i) ~>
        if @type == \column => "translate(#{scale.x(d.name)},0)"
        else "translate(0,#{scale.y(d.name)})"
    @g.subview.selectAll \g.bar
      .each (item,j) ->
        [bars,offset] = [[],0]
        # alternative align base. required for dancing stack
        offset = (delta - base-offset[j])

        # use to tweak output size / offset. 1 = no modification
        sum = 1
        # and set sum to this for 100% stack bar
        if cfg.percent == true =>
          sum = item.size
            .filter((d,i) -> legend.is-visible(i))
            .reduce(((a,b) -> a + b),0) >? 1

        for idx from 0 til item.size.length =>
          size = item.size[idx]
          key = idx
          if !legend.is-visible(key) => continue

          bars.push datum = {
            raw: size
            percent: size / sum
            size: size / sum
            offset: offset / sum
            key: key
            group: item.name
            name: binding.size[key].name or binding.size[key].key
            unit: binding.size[key].unit or ''
            order: bars.length
            subset: (if item.subset => ((item.subset.size or [])[idx] or 0) / sum else null)
            # legend 關掉但 legend.subset.mode 是 dim: 位置與總量都留著, 只是灰掉
            dimmed: !legend.is-selected(key)
          }
          # for auto-select + default data-accessor
          datum._raw = {} <<< datum
          # multiple bars
          if cfg.multiple == \split => offset += max-per-group[idx]
          # stack bar
          else if cfg.multiple == \stack => offset += size

        d3.select @ .selectAll \rect.data .data(bars, (d,i) -> d.key)
          ..exit!each (d,i) -> d._removing = true
          ..exit!
            .transition!delay 150
            .remove!

          ..enter!append \rect
            ..attr \class, -> \data
            ..attr(\width, (d,i) -> (scale.x.bandwidth! - 2) >? 1)  if type == \column
            ..attr(\y, (d,i) -> scale.y(0))                         if type == \column
            ..attr(\height, (d,i) -> (scale.y.bandwidth! - 2) >? 1) if type != \column
            ..attr(\x, (d,i) -> scale.x(0))                         if type != \column

        tran = d3.select @ .selectAll \rect.data
          .transition!duration 350
          # group bar
          .call (sel) ->
            if cfg.multiple != \group => return
            sel
              ..attr(\x, (d,i) -> gap/2 + d.order * (scale.x.bandwidth! - gap) / bars.length)  if type == \column
              ..attr(\width, (d,i) -> (scale.x.bandwidth! - gap) / bars.length)          if type == \column
              ..attr(\y, (d,i) -> Math.round(Math.min(scale.y(0), scale.y(d.size))))     if type == \column

              ..attr(\y, (d,i) -> gap/2 + d.order * (scale.y.bandwidth! - gap) / bars.length)  if type != \column
              ..attr(\height, (d,i) -> (scale.y.bandwidth! - gap) / bars.length)       if type != \column
              ..attr(\x, (d,i) -> Math.round(Math.min(scale.x(0), scale.x(d.size)))) if type != \column

          # stack bar
          .call (sel) ->
            if cfg.multiple != \stack => return
            sel
              ..attr(\x, gap/2) if type == \column
              ..attr(\width, (d,i) -> scale.x.bandwidth! - gap) if type == \column
              ..attr(\y, (d,i) ->
                if d._removing => return scale.y(d.offset + d.size/2)
                Math.round(Math.min(scale.y(d.offset), scale.y(d.offset + d.size)))) if type == \column
              ..attr(\y, gap/2) if type != \column
              ..attr(\height, (d,i) -> scale.y.bandwidth! - gap) if type != \column
              ..attr(\x, (d,i) ->
                if d._removing => return scale.x(d.offset + d.size/2)
                Math.round(Math.min(scale.x(d.offset), scale.x(d.offset + d.size)))) if type != \column

        if type == \column =>
          tran.attr \height, (d,i) -> if d._removing => 0 else Math.round(Math.abs(scale.y(0) - scale.y(d.size)))
        else
          tran.attr \width, (d,i) -> if d._removing => 0 else Math.round(Math.abs(scale.x(0) - scale.x(d.size)))
        color = (d) -> tint.get d.name, (if cfg.color-variant => ((j/data.length) - 0.5) else 0)
        tran
          .attr \fill, (d,i) ->
            # legend 關掉的只降透明 ( 見下面 fill-opacity ), 顏色留著才認得出是哪一項
            if !d.dimmed and partial and d.subset? => self.subset.color(color d) else color d
          .attr \fill-opacity, (d,i) ~>
            if d.dimmed => return legend.opacity!
            if partial => return 1
            if !(binding.name and filter = binding.name.filter) => return 1
            if !(range = filter.value) => return 1
            if item.name in range => 1 else (((cfg.common or {}).subset or {}).opacity ? 0.2)

        # partial: 在同一格裡切出被選中的那一段, 不新增堆疊層 -
        # 真正的 stack bar 上再疊一層「其它」會讓堆疊的語意打架
        subsets = if !partial => [] else bars.filter (d) -> d.subset? and !d.dimmed
        psel = d3.select @ .selectAll \rect.subset .data(subsets, (d,i) -> d.key)
        psel.exit!remove!
        psel.enter!append \rect
          ..attr \class, \subset
          ..attr \pointer-events, \none
          ..attr(\width, (d,i) -> (scale.x.bandwidth! - 2) >? 1)  if type == \column
          ..attr(\y, (d,i) -> scale.y(0))                         if type == \column
          ..attr(\height, (d,i) -> (scale.y.bandwidth! - 2) >? 1) if type != \column
          ..attr(\x, (d,i) -> scale.x(0))                         if type != \column
        ptran = d3.select @ .selectAll \rect.subset
          .transition!duration 350
          .call (sel) ->
            if cfg.multiple != \group => return
            sel
              ..attr(\x, (d,i) -> gap/2 + d.order * (scale.x.bandwidth! - gap) / bars.length) if type == \column
              ..attr(\width, (d,i) -> (scale.x.bandwidth! - gap) / bars.length)               if type == \column
              ..attr(\y, (d,i) -> Math.round(Math.min(scale.y(0), scale.y(d.subset))))          if type == \column
              ..attr(\y, (d,i) -> gap/2 + d.order * (scale.y.bandwidth! - gap) / bars.length) if type != \column
              ..attr(\height, (d,i) -> (scale.y.bandwidth! - gap) / bars.length)              if type != \column
              ..attr(\x, (d,i) -> Math.round(Math.min(scale.x(0), scale.x(d.subset))))          if type != \column
          .call (sel) ->
            if cfg.multiple != \stack => return
            sel
              ..attr(\x, gap/2)                                                  if type == \column
              ..attr(\width, (d,i) -> scale.x.bandwidth! - gap)                  if type == \column
              ..attr(\y, (d,i) -> Math.round(Math.min(scale.y(d.offset), scale.y(d.offset + d.subset)))) if type == \column
              ..attr(\y, gap/2)                                                  if type != \column
              ..attr(\height, (d,i) -> scale.y.bandwidth! - gap)                 if type != \column
              ..attr(\x, (d,i) -> Math.round(Math.min(scale.x(d.offset), scale.x(d.offset + d.subset)))) if type != \column
        if type == \column =>
          ptran.attr \height, (d,i) -> Math.round(Math.abs(scale.y(0) - scale.y(d.subset)))
        else
          ptran.attr \width, (d,i) -> Math.round(Math.abs(scale.x(0) - scale.x(d.subset)))
        ptran.attr \fill, (d,i) -> color d

    if @cfg.brush.enabled =>
      @g.brush.style \display, \block
      @g.brush.call @brush
    else @g.brush.style \display, \none
    @g.brush.selectAll \rect.selection
      .attr \shape-rendering, \auto
    @legend.render!
    @yaxis.render!
    @xaxis.render!

  tick: ->
