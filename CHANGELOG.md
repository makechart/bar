# Change Logs

## v0.0.10

 - histogram from raw values: new `value` dimension and `bin` config ( `chart.utils.config.preset.bin` ).
   when `bin.enabled` and `value` is bound, values are grouped into bins by `chart.utils.bin`
   ( needs `@plotdb/chart` >= 3.10.0 ): `name` becomes the bin label, `size` is summed per bin
   when bound, otherwise rows are counted. subset rows are binned with the same edges.
 - in bin mode the brush emits a range filter on `value` ( `{type: 'range', value: [x0, x1], closed}` )
   instead of bin labels, and an external range filter moves the brush to the overlapping bins.
 - in bin mode sorting is ignored ( bins keep their numeric order ).
 - add `bin:*` test cases


## v0.0.9

 - extend the lite base ( `@makechart/base` `lite/index.html`, no d3 ): needs `@makechart/base` >= 0.2.0
   and `@plotdb/chart` >= 3.7.0. scales / shapes / transitions use `chart.utils`, and transitions run on
   `chart.anim`, so animation can be recorded frame by frame ( `anim.manual` / `step` )
 - brush uses `chart.utils.brush`
 - add test cases ( `test/index.ls`, run with `npm test` via `@makechart/viewer` )


## v0.0.8

 - support subset presentation: `partial` draws a second layer inside each bar showing how
   much of it is selected, filled with the grey of the bar's own color rather than another
   palette entry
 - sync selection back from a filter: `mod.filter` moves the brush to the incoming range.
   it leaves the brush alone when the current box already covers the same bands, so a host
   that re-applies the selection on every render no longer snaps the box the user just dragged
 - dim legend items instead of removing them when `cfg.legend.subset.mode` is `dim`
 - fix bug: `mod.filter` moved the brush on `g.view` instead of `g.brush`, throwing
   `Cannot read properties of undefined ( reading 'extent' )`
 - fix bug: the far edge of a re-applied range landed exactly on a band boundary, where
   `Math.floor` counts it into the next band — the selection grew by one bar per round trip
 - fix bug: tip never appeared while brush was enabled. the brush overlay covers the plot
   area and takes every hover, so the accessor only ever saw the overlay; it now hit-tests
   with `elementsFromPoint` to find the bar under the pointer


## v0.0.7

 - separate percent calculation from raw in tooltip and validate value before using


## v0.0.6

 - use value-alt instead of construct tooltip string manually


## v0.0.5

 - fix bug: value in tooltip under percent mode shows 0
 - add percent number in tooltip if percent mode is on


## v0.0.4

 - use separated field `name` and `group` for tip rendering


## v0.0.3

 - use xaxis / yaxis format (chosen based on type) for tip formatting


## v0.0.2

 - fix bug: brush isn't hidden even if disabled
 - improve sample data
 - correctly support auto-select feature
 - fix bug: sort direction incorrect in bar mode


## v0.0.1

init release
