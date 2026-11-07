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
