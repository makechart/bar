# bar 的 test case ( 用 @makechart/viewer 的 mctest 跑, 見 README / `npx mctest -h` )
#
# 資料都由固定種子產生, 改這裡會讓全部 snapshot 跟著變.

rnd = mctest.random 7
cats = <[apple banana peach orange]>
fruit = (n = 11, opt = {}) ->
  raw: [0 til n].map (i) ->
    r = {name: "Y#{1995 + i}"}
    for k in cats => r[k] = +(rnd! * 10).toFixed(1)
    if opt.neg => r.banana = -r.banana
    r
  binding:
    size: cats.map (k) -> {key: k, unit: \KG}
    name: {key: \name}

# 0 ~ 100 的成績, 中間多兩邊少
scores = ->
  r = mctest.random 9
  raw: [0 til 200].map (i) ->
    score = Math.round(((r! + r! + r!) / 3) * 100)
    {id: "s#i", score, hours: +(r! * 5).toFixed(1), extra: +(r! * 2).toFixed(1)}
  binding: value: {key: \score, name: "score"}

subset-of = (d) ->
  r = mctest.random 3
  d.subset = d.raw.map (row) ->
    ret = {name: row.name}
    for k in cats => ret[k] = +(row[k] * r!).toFixed(1)
    ret
  d

data =
  fruit: fruit!
  single: do ->
    d = fruit 6
    d.binding.size = [d.binding.size.0]
    d
  many: fruit 40
  neg: fruit 8, {neg: true}
  longname: do ->
    d = fruit 5
    d.raw.map (r, i) -> r.name = "a quite long category name #i"
    d
  empty: {raw: [], binding: fruit!binding}
  subset: subset-of fruit!
  # 直方圖: 原始數值, 沒有分組過. 綁 value 就會自動分組
  scores: scores!
  # 有綁 size: 各組加總而不是計數 ( 兩個 series )
  weighted: do ->
    d = scores!
    d.binding.size = [{key: \hours, unit: \h}, {key: \extra, unit: \h}]
    d
  # 連續值 ( 小數 )
  height: do ->
    r = mctest.random 5
    raw: [0 til 120].map -> {cm: +(150 + (r! + r! + r! + r!) * 10).toFixed(1)}
    binding: value: {key: \cm, unit: \cm}
  # 子集也是原始列, 要用同一組區間分
  ssub: do ->
    d = scores!
    d.subset = d.raw.filter (r, i) -> i % 3 == 0
    d

cases = []

# 基本排列: type x multiple x percent
mctest.combo({type: <[column bar]>, multiple: <[stack group]>, percent: [false, true]}).map (o) ->
  cases.push {name: "layout:#{mctest.label o}", data: \fruit, config: o}

# 各種資料形狀
for k in <[single many neg longname empty]> =>
  for type in <[column bar]> =>
    cases.push {name: "data:#k,type=#type", data: k, config: {type}}

cases ++= [
  * name: "sort:size-desc", config: {sort: {enabled: true, dimension: \size, dir: \desc}}
  * name: "sort:name-desc", config: {sort: {enabled: true, dimension: \name, dir: \desc}}
  * name: "gap:20", config: {gap: 20}
  * name: "brush:off", config: {brush: {enabled: false}}
  * name: "subset:partial", data: \subset, config: {common: {subset: {mode: \partial}}}
  * name: "subset:dim", data: \subset, config: {common: {subset: {mode: \dim}}}

  # 外部 filter -> brush 框跟著動, 框外變淡; 再清掉
  * name: "filter:external"
    steps:
      * (c, ctx) ->
          c.filter {name: {type: \index, value: <[Y1997 Y1998 Y1999]>}}
          ctx.snap \filtered
      * (c) -> c.filter {name: undefined}

  # 換資料: 舊的縮掉、新的長出來 ( 動畫 flush 到終點 )
  * name: "update:new-data"
    steps: [(c) -> d = fruit 7; c.set-raw d.raw, d.binding]

  # 直條換橫條時 brush 的拉桿要跟著換方向
  * name: "update:column-to-bar"
    steps:
      * (c, ctx) ->
          c.filter {name: {type: \index, value: <[Y1997 Y1998]>}}
          ctx.snap \column
      * (c) ->
          c.config {type: \bar}
          c.parse!; c.bind!; c.resize!; c.render!

  # 真的拖 brush ( pointer 事件 ), 圖要發出 filter
  * name: "brush:drag"
    steps:
      * (c, ctx) ->
          c._mctest-filter = []
          c.on \filter, -> c._mctest-filter.push it
          # brush 的 filter 有 debounce 150ms, engine 會等 DOM 安靜下來 ( quiet ) 才往下
          ctx.drag ctx.root.querySelector('rect.overlay'), [0.1, 0.5], [0.45, 0.5]
      * (c) ->
          f = c._mctest-filter[* - 1]
          if !(f and f.name and f.name.value.length) => throw new Error("drag 之後沒有發 filter")
]

# 直方圖 ( 綁 value 時自動分組 )
cases ++= [
  * name: "bin:auto", data: \scores, config: {gap: 0, bin: {enabled: true}}
  * name: "bin:width=10", data: \scores, config: {gap: 0, bin: {enabled: true, width: 10}}
  * name: "bin:width=10,closed=right", data: \scores, config: {gap: 0, bin: {enabled: true, width: 10, closed: \right}}
  * name: "bin:anchor=5", data: \scores, config: {gap: 0, bin: {enabled: true, width: 10, anchor: 5}}
  * name: "bin:label=center", data: \scores, config: {gap: 0, bin: {enabled: true, width: 10, label: \center}}
  * name: "bin:label=start,format", data: \height, config: {gap: 0, bin: {enabled: true, width: 2.5, label: \start, format: \.1f}}
  * name: "bin:continuous", data: \height, config: {gap: 0, bin: {enabled: true}}
  * name: "bin:empty=false", data: \scores, config: {gap: 0, bin: {enabled: true, width: 4, empty: false}}
  * name: "bin:weighted", data: \weighted, config: {gap: 0, bin: {enabled: true, width: 10}}
  * name: "bin:type=bar", data: \scores, config: {type: \bar, gap: 0, bin: {enabled: true, width: 10}}
  * name: "bin:subset-partial", data: \ssub, config: {gap: 0, bin: {enabled: true, width: 10}, common: {subset: {mode: \partial}}}
  * name: "bin:subset-shrink", data: \ssub, config: {gap: 0, bin: {enabled: true, width: 10}, common: {subset: {mode: \shrink}}}

  # 外部給原始數值的區間 -> brush 框到重疊的組
  * name: "bin:filter-external", data: \scores, config: {gap: 0, bin: {enabled: true, width: 10}}
    steps:
      * (c, ctx) ->
          c.filter {value: {type: \range, value: [40, 70], closed: \left}}
          ctx.snap \filtered
      * (c) -> c.filter {value: undefined}

  # 拖 brush: 發的是原始數值的區間 ( range ), 不是組的標籤
  * name: "bin:brush-drag", data: \scores, config: {gap: 0, bin: {enabled: true, width: 10}}
    steps:
      * (c, ctx) ->
          c._mctest-filter = []
          c.on \filter, -> c._mctest-filter.push it
          ctx.drag ctx.root.querySelector('rect.overlay'), [0.25, 0.5], [0.55, 0.5]
      * (c) ->
          f = (c._mctest-filter[* - 1] or {}).value
          if !(f and f.type == \range and f.value.length == 2) => throw new Error("drag 之後沒有發 range filter")
          if !(f.value.0 < f.value.1 and f.value.0 % 10 == 0 and f.value.1 % 10 == 0) =>
            throw new Error("range 沒有對齊組的邊界: #{JSON.stringify f}")
]

# crossfilter: 兩張 bar 用 @plotdb/dash 串起來
rows = do ->
  r = mctest.random 11
  ret = []
  for region in <[North South East West]> => for cat in <[book music film]> => for m from 1 to 3 =>
    ret.push {region, cat, month: "M#m", amount: Math.round(r! * 100)}
  ret

board-def =
  data: {type: \inline, rows}
  layout: {col: <[1fr 1fr]>, row: <[1fr]>, gap: \8px}
  panels:
    * id: \region, title: "region"
      chart: {name: "@makechart/bar"}
      data: {groupby: \region, measures: [{name: \amount, field: \amount, op: \sum}]}
      compare: {exclude-self: true}
      cfg: {common: {subset: {mode: \partial}}, legend: {enabled: false}}
    * id: \cat, title: "category"
      chart: {name: "@makechart/bar"}
      data: {groupby: \cat, measures: [{name: \amount, field: \amount, op: \sum}]}
      compare: {exclude-self: true}
      cfg: {type: \bar, common: {subset: {mode: \partial}}, legend: {enabled: false}}

cases ++= [
  * name: "dash:init", dash: {def: board-def, size: [900, 320]}
  # board 直接設 filter: 另一張圖要畫出子集
  * name: "dash:board-filter", dash: {def: board-def, size: [900, 320]}
    steps:
      * (b, ctx) ->
          b.set-filter \region, {field: \region, values: <[North East]>}
          ctx.snap \region-filtered
      * (b) -> b.clear-filter!
  # 從圖發 filter ( 等同使用者操作 ): board 收到後更新其他圖, 自己的 brush 框留著
  * name: "dash:chart-filter", dash: {def: board-def, size: [900, 320]}
    steps: [
      (b, ctx) ->
        ctx.chart(\cat).filter {name: {type: \index, value: <[music]>}}, true
    ]
  # 拖 brush
  * name: "dash:brush-drag", dash: {def: board-def, size: [900, 320]}
    steps:
      * (b, ctx) ->
          ctx.drag ctx.root.querySelector('rect.overlay'), [0.05, 0.5], [0.5, 0.5]
      * (b) ->
          if !b.filter-of(\region) => throw new Error("brush 之後 board 沒有 region 的 filter")
]

mctest.suite {data, cases, size: [480, 300]}
