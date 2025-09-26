(function(){
  var mod;
  module.exports = {
    pkg: {
      name: 'bar',
      version: '0.0.1',
      extend: {
        name: "base",
        version: "0.0.1"
      },
      dependencies: [],
      i18n: {
        "zh-TW": {
          "size": "長度"
        }
      }
    },
    init: function(arg$){
      var root, context, t, pubsub;
      root = arg$.root, context = arg$.context, t = arg$.t, pubsub = arg$.pubsub;
      return pubsub.fire('init', {
        mod: mod({
          context: context,
          t: t
        })
      });
    }
  };
  mod = function(arg$){
    var context, t, chart, d3, debounce, ref$;
    context = arg$.context, t = arg$.t;
    chart = context.chart, d3 = context.d3, debounce = context.debounce;
    return {
      sample: function(){
        return {
          raw: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(function(val){
            var ret, i$, i;
            ret = {
              name: val
            };
            for (i$ = 1; i$ <= 4; ++i$) {
              i = i$;
              ret["val" + i] = (10 * Math.random()).toFixed(1);
            }
            return ret;
          }),
          binding: {
            size: [1, 2, 3, 4].map(function(it){
              return {
                key: "val" + it,
                unit: "amount"
              };
            }),
            name: {
              key: "name"
            }
          }
        };
      },
      config: (ref$ = import$({
        legend: import$({}, chart.utils.config.preset.legend),
        xaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis)),
        yaxis: JSON.parse(JSON.stringify(chart.utils.config.preset.axis))
      }, chart.utils.config.preset['default']), ref$.sort = {
        enabled: {
          type: 'boolean',
          'default': false
        },
        dir: {
          type: 'choice',
          values: ['asc', 'desc'],
          'default': 'asc'
        },
        dimension: {
          type: 'choice',
          values: ['name', 'size'],
          'default': 'size'
        }
      }, ref$.type = {
        type: 'choice',
        values: ['bar', 'column'],
        'default': 'column'
      }, ref$.brush = {
        enabled: {
          type: 'boolean',
          'default': true
        }
      }, ref$.multiple = {
        type: 'choice',
        values: ['stack', 'group'],
        'default': 'stack'
      }, ref$.percent = {
        type: 'boolean',
        'default': false
      }, ref$.dancing = {
        type: 'boolean',
        'default': true
      }, ref$.gap = {
        type: 'number',
        'default': 2,
        min: 0,
        max: 100,
        step: 1
      }, ref$),
      dimension: {
        size: {
          type: 'R',
          multiple: true,
          name: "size"
        },
        name: {
          type: 'NCO',
          name: "name"
        }
      },
      init: function(){
        var tint, brush, scale, this$ = this;
        this.tint = tint = new chart.utils.tint();
        this.svg.addEventListener('click', function(e){
          var n, idx;
          n = e.target;
          while (n !== this$.svg) {
            if (!n) {
              return;
            }
            if (!(n.classList && n.classList.contains('pdl-cell'))) {
              n = n.parentNode;
              continue;
            }
            if (n.getAttribute('data-name') === 'view') {
              break;
            } else {
              return;
            }
          }
          if (!this$.cfg.dancing || this$.cfg.percent) {
            return;
          }
          idx = this$.alignIdx || 0;
          for (;;) {
            this$.alignIdx = ((this$.alignIdx || 0) + 1) % (this$.binding.size.length + 1);
            if (this$.legend.isSelected(this$.alignIdx) || this$.alignIdx === idx) {
              break;
            }
          }
          this$.resize();
          return this$.render();
        });
        this.g = Object.fromEntries(['view', 'xaxis', 'yaxis', 'legend'].map(function(it){
          return [it, d3.select(this$.layout.getGroup(it))];
        }));
        this.g.subview = this.g.view.append('g');
        this.g.brush = this.g.view.append('g');
        this.brushs = {
          x: d3.brushX(),
          y: d3.brushY()
        };
        this.brushType = function(){
          if (this$.cfg.type === 'bar') {
            return 'y';
          } else {
            return 'x';
          }
        };
        this.range = "null";
        brush = debounce(150, function(e){
          var range, _range, domain, bandwidth, ret, box;
          if (!this$.cfg.brush.enabled) {
            return;
          }
          range = e.selection;
          if ((_range = JSON.stringify(range)) === this$.range) {
            return;
          } else {
            this$.range = _range;
          }
          if (!range) {
            return this$.filter({
              name: undefined
            }, true);
          } else {
            domain = this$.scale[this$.brushType()].domain();
            bandwidth = this$.scale[this$.brushType()].bandwidth();
            if (this$.brushType() === 'x') {
              range = range.map(function(it){
                var ref$, ref1$, ref2$;
                return (ref$ = (ref2$ = Math.floor(it / bandwidth)) > 0 ? ref2$ : 0) < (ref1$ = domain.length - 1) ? ref$ : ref1$;
              });
              ret = (function(){
                var i$, to$, results$ = [];
                for (i$ = range[0], to$ = range[1]; i$ <= to$; ++i$) {
                  results$.push(i$);
                }
                return results$;
              }()).map(function(it){
                return domain[it];
              });
            } else {
              box = this$.layout.getBox('view');
              range = range.map(function(it){
                var ref$, ref1$, ref2$;
                return (ref$ = (ref2$ = Math.floor((box.height - it) / bandwidth)) > 0 ? ref2$ : 0) < (ref1$ = domain.length - 1) ? ref$ : ref1$;
              });
              ret = (function(){
                var i$, to$, results$ = [];
                for (i$ = range[1], to$ = range[0]; i$ <= to$; ++i$) {
                  results$.push(i$);
                }
                return results$;
              }()).map(function(it){
                return domain[it];
              });
            }
            return this$.filter({
              name: {
                type: 'index',
                value: ret
              }
            }, true);
          }
        });
        this.brushs.x.on('end', function(e){
          if (this$.brushType() === 'x') {
            return brush(e);
          }
        });
        this.brushs.x.on('brush', function(e){
          if (this$.brushType() === 'x') {
            return brush(e);
          }
        });
        this.brushs.y.on('end', function(e){
          if (this$.brushType() === 'y') {
            return brush(e);
          }
        });
        this.brushs.y.on('brush', function(e){
          if (this$.brushType() === 'y') {
            return brush(e);
          }
        });
        this.scale = scale = {};
        this.yaxis = new chart.utils.axis({
          layout: this.layout,
          name: 'yaxis',
          direction: 'left'
        });
        this.xaxis = new chart.utils.axis({
          layout: this.layout,
          name: 'xaxis',
          direction: 'bottom'
        });
        this.legend = new chart.utils.legend({
          layout: this.layout,
          name: 'legend',
          root: this.root,
          shape: function(d){
            return d3.select(this).attr('fill', tint.get(d.text || d.key));
          }
        });
        this.legend.on('select', function(){
          this$.bind();
          this$.resize();
          return this$.render();
        });
        return this.tip = new chart.utils.tip({
          root: this.root,
          accessor: function(arg$){
            var evt, data, ref$, v;
            evt = arg$.evt;
            if (!(evt.target && (data = d3.select(evt.target).datum()))) {
              return null;
            }
            if ((ref$ = data.type) === 'overlay' || ref$ === 'selection' || ref$ === 's') {
              return;
            }
            v = isNaN(data.size)
              ? '-'
              : data.size.toFixed(2) + "" + (data.unit || '');
            return {
              name: (data.group || '') + " / " + (data.name || ''),
              value: v
            };
          },
          range: function(){
            return this$.layout.getNode('view').getBoundingClientRect();
          }
        });
      },
      destroy: function(){
        if (this.tip) {
          return this.tip.destroy();
        }
      },
      filter: function(filters, internal){
        var this$ = this;
        internal == null && (internal = false);
        this.render();
        if (internal) {
          return;
        }
        return this.brush.move(this.g.view, filters.name ? filters.name.map(function(it){
          return this$.scale[this$.brushType()](it);
        }) : null);
      },
      parse: function(){
        this.data.map(function(d){
          return d.size = d.size.map(function(it){
            if (isNaN(it)) {
              return 0;
            } else {
              return it;
            }
          });
        });
        return this.alignIdx = undefined;
      },
      resize: function(){
        var i, alignIdx, ref$, ref1$, delta, max, box, maxTick, yticks, v, that, xticks, i$, w, h, r, this$ = this;
        this.root.querySelector('.pdl-layout').classList.toggle('legend-bottom', this.cfg.legend.position === 'bottom');
        this.type = this.cfg.type || 'column';
        this.brush = this.brushs[this.brushType()];
        this.legend.config(this.cfg.legend);
        this.legend.data((function(){
          var i$, results$ = [];
          for (i$ = this.binding.size.length - 1; i$ >= 0; --i$) {
            i = i$;
            results$.push({
              key: i,
              text: this.binding.size[i].name || this.binding.size[i].key
            });
          }
          return results$;
        }.call(this)));
        this.layout.update(false);
        this.maxPerGroup = this.binding.size.filter(function(d, i){
          return this$.legend.isSelected(i);
        }).map(function(d, i){
          return Math.max.apply(Math, this$.data.map(function(it){
            return it.size[i];
          }));
        });
        if (this.cfg.alignIdx && !this.alignIdx) {
          this.alignIdx = this.cfg.alignIdx;
        }
        alignIdx = (ref$ = this.cfg.percent
          ? 0
          : this.alignIdx || 0) < (ref1$ = this.binding.size.length) ? ref$ : ref1$;
        this.baseOffset = this.data.map(function(d){
          return (function(){
            var i$, to$, results$ = [];
            for (i$ = 0, to$ = alignIdx; i$ < to$; ++i$) {
              results$.push(i$);
            }
            return results$;
          }()).reduce(function(a, b){
            return a + (!this$.legend.isSelected(b)
              ? 0
              : d.size[b]);
          }, 0) || [0];
        });
        this.delta = delta = Math.max.apply(Math, this.baseOffset);
        if (this.cfg.multiple === 'stack') {
          if (this.cfg.percent) {
            max = 1;
          } else {
            max = Math.max.apply(Math, this.data.map(function(d){
              return (function(){
                var i$, to$, results$ = [];
                for (i$ = alignIdx, to$ = d.size.length; i$ < to$; ++i$) {
                  results$.push(i$);
                }
                return results$;
              }()).reduce(function(a, b){
                return a + (!this$.legend.isSelected(b)
                  ? 0
                  : d.size[b]);
              }, 0);
            })) + (delta || 0);
          }
        } else if (this.cfg.multiple === 'group') {
          max = Math.max.apply(Math, this.data.map(function(d){
            return Math.max.apply(Math, d.size.filter(function(v, i){
              return this$.legend.isSelected(i);
            }));
          }));
        } else if (this.cfg.multiple === 'split') {
          max = this.maxPerGroup.reduce(function(a, b){
            return a + b;
          }, 0);
        }
        this.order = this.data.map(function(d, i){
          return {
            key: d._idx,
            idx: i,
            name: d.name
          };
        });
        this.data.map(function(d, i){
          return d.sum = d.size.filter(function(d, i){
            return this$.legend.isSelected(i);
          }).reduce(function(a, b){
            return a + b;
          }, 0);
        });
        if (((ref$ = this.cfg).sort || (ref$.sort = {})).enabled) {
          this.order.sort(function(a, b){
            var d, na, nb;
            d = this$.cfg.sort.dimension === 'size'
              ? this$.data[a.idx].sum - this$.data[b.idx].sum
              : (na = this$.data[a.idx].name, nb = this$.data[b.idx].name, na = isNaN(+na)
                ? na
                : +na, nb = isNaN(+nb)
                ? nb
                : +nb, na > nb
                ? 1
                : na < nb ? -1 : 0);
            return (this$.cfg.sort.dir === 'asc'
              ? 1
              : -1) * d;
          });
        }
        if (this.cfg.palette) {
          this.tint.set(this.cfg.palette);
        }
        this.layout.update(false);
        box = this.layout.getBox('view');
        if (this.type === 'column') {
          ref$ = this.scale;
          ref$.y = d3.scaleLinear().domain([0, max]).range([box.height, 0]);
          ref$.x = d3.scaleBand().domain(this.order.map(function(it){
            return it.name || it.key;
          })).range([0, box.width]);
          maxTick = (ref$ = Math.ceil(this.layout.getBox('yaxis').height / 40)) > 2 ? ref$ : 2;
          yticks = this.cfg.bump
            ? (function(){
              var i$, to$, ref$, results$ = [];
              for (i$ = 1, to$ = (ref$ = this.parsed.length || 1) > 1 ? ref$ : 1; i$ <= to$; ++i$) {
                results$.push(i$);
              }
              return results$;
            }.call(this))
            : this.scale.y.ticks((ref$ = ((ref1$ = this.cfg).yaxis || (ref1$.yaxis = {})).tick.count || 4) < maxTick ? ref$ : maxTick);
          this.yaxis.config(this.cfg.yaxis);
          v = this.binding.size[0] || {};
          if (this.binding.size.length > 1) {
            this.yaxis.caption(v.unit ? v.unit + "" : '');
          } else {
            this.yaxis.caption((v.name || v.key || '') + (v.unit ? "(" + v.unit + ")" : ''));
          }
          this.yaxis.ticks(yticks);
          this.yaxis.scale(this.scale.y);
          this.xaxis.config(this.cfg.xaxis);
          this.xaxis.ticks(this.data.map(function(it){
            return it.name;
          }));
          this.xaxis.scale(this.scale.x);
          this.xaxis.caption((that = this.binding.name) ? (that.name || that.key || '') + (that.unit ? "(" + this.binding.name.unit + ")" : '') : '');
        } else {
          ref$ = this.scale;
          ref$.x = d3.scaleLinear().domain([0, max]).range([box.width, 0]);
          ref$.y = d3.scaleBand().domain(this.order.map(function(it){
            return it.name || it.key;
          })).range([0, box.height]);
          maxTick = (ref$ = Math.ceil(this.layout.getBox('xaxis').width / 80)) > 2 ? ref$ : 2;
          xticks = this.cfg.bump
            ? (function(){
              var i$, to$, ref$, results$ = [];
              for (i$ = 1, to$ = (ref$ = this.parsed.length || 1) > 1 ? ref$ : 1; i$ <= to$; ++i$) {
                results$.push(i$);
              }
              return results$;
            }.call(this))
            : this.scale.x.ticks((ref$ = ((ref1$ = this.cfg).xaxis || (ref1$.xaxis = {})).tick.count || 4) < maxTick ? ref$ : maxTick);
          this.xaxis.config(this.cfg.xaxis);
          v = this.binding.size[0] || {};
          if (this.binding.size.length > 1) {
            this.xaxis.caption(v.unit ? v.unit + "" : '');
          } else {
            this.xaxis.caption((v.name || v.key || '') + (v.unit ? "(" + v.unit + ")" : ''));
          }
          this.xaxis.ticks(xticks);
          this.xaxis.scale(this.scale.x);
          this.yaxis.config(this.cfg.yaxis);
          this.yaxis.ticks(this.data.map(function(it){
            return it.name;
          }));
          this.yaxis.scale(this.scale.y);
          this.yaxis.caption((that = this.binding.name) ? (that.name || that.key || '') + (that.unit ? "(" + this.binding.name.unit + ")" : '') : '');
        }
        for (i$ = 0; i$ < 2; ++i$) {
          i = i$;
          this.layout.update(false);
          box = this.layout.getBox('view');
          ref$ = [box.width, box.height], w = ref$[0], h = ref$[1];
          this.tint.set(this.cfg.palette);
          r = this.cfg.dotSize || 3;
          this.scale.x.range([0, w - r]);
          this.scale.y.range([h, r]);
          this.xaxis.render();
          this.yaxis.render();
        }
        box = this.layout.getBox('view');
        if (this.brushType() === 'x') {
          return this.brush.extent([[0, 1], [box.width, box.height - 2]]);
        } else {
          return this.brush.extent([[1, 0], [box.width - 2, box.height]]);
        }
      },
      render: function(){
        var binding, scale, range, delta, baseOffset, maxPerGroup, cfg, tint, data, type, legend, gap, ref$, x$, this$ = this;
        binding = this.binding, scale = this.scale, range = this.range, delta = this.delta, baseOffset = this.baseOffset, maxPerGroup = this.maxPerGroup, cfg = this.cfg, tint = this.tint, data = this.data, type = this.type, legend = this.legend;
        gap = this.cfg.gap;
        gap <= (ref$ = (this.type === 'column'
          ? scale.x.bandwidth()
          : scale.y.bandwidth()) - 1) || (gap = ref$);
        x$ = this.g.subview.selectAll('g.bar').data(this.data);
        x$.exit().remove();
        x$.enter().append('g').attr('class', 'bar').attr('transform', function(d, i){
          if (this$.type === 'column') {
            return "translate(" + scale.x(d.name) + ",0)";
          } else {
            return "translate(0," + scale.y(d.name) + ")";
          }
        });
        this.g.subview.selectAll('g.bar').transition().duration(350).attr('transform', function(d, i){
          if (this$.type === 'column') {
            return "translate(" + scale.x(d.name) + ",0)";
          } else {
            return "translate(0," + scale.y(d.name) + ")";
          }
        });
        this.g.subview.selectAll('g.bar').each(function(item, j){
          var ref$, bars, offset, sum, i$, to$, idx, size, key, x$, y$, tran;
          ref$ = [[], 0], bars = ref$[0], offset = ref$[1];
          offset = delta - baseOffset[j];
          sum = 1;
          if (cfg.percent === true) {
            sum = (ref$ = item.size.filter(function(d, i){
              return legend.isSelected(i);
            }).reduce(function(a, b){
              return a + b;
            }, 0)) > 1 ? ref$ : 1;
          }
          for (i$ = 0, to$ = item.size.length; i$ < to$; ++i$) {
            idx = i$;
            size = item.size[idx];
            key = idx;
            if (!legend.isSelected(key)) {
              continue;
            }
            bars.push({
              size: size / sum,
              offset: offset / sum,
              key: key,
              group: item.name,
              name: binding.size[key].name || binding.size[key].key,
              unit: binding.size[key].unit || '',
              order: bars.length
            });
            if (cfg.multiple === 'split') {
              offset += maxPerGroup[idx];
            } else if (cfg.multiple === 'stack') {
              offset += size;
            }
          }
          x$ = d3.select(this).selectAll('rect').data(bars, function(d, i){
            return d.key;
          });
          x$.exit().each(function(d, i){
            return d._removing = true;
          });
          x$.exit().transition().delay(150).remove();
          y$ = x$.enter().append('rect');
          if (type === 'column') {
            y$.attr('width', function(d, i){
              var ref$;
              return (ref$ = scale.x.bandwidth() - 2) > 1 ? ref$ : 1;
            });
          }
          if (type === 'column') {
            y$.attr('y', function(d, i){
              return scale.y(0);
            });
          }
          if (type !== 'column') {
            y$.attr('height', function(d, i){
              var ref$;
              return (ref$ = scale.y.bandwidth() - 2) > 1 ? ref$ : 1;
            });
          }
          if (type !== 'column') {
            y$.attr('x', function(d, i){
              return scale.x(0);
            });
          }
          tran = d3.select(this).selectAll('rect').transition().duration(350).call(function(sel){
            var x$;
            if (cfg.multiple !== 'group') {
              return;
            }
            x$ = sel;
            if (type === 'column') {
              x$.attr('x', function(d, i){
                return gap / 2 + d.order * (scale.x.bandwidth() - gap) / bars.length;
              });
            }
            if (type === 'column') {
              x$.attr('width', function(d, i){
                return (scale.x.bandwidth() - gap) / bars.length;
              });
            }
            if (type === 'column') {
              x$.attr('y', function(d, i){
                return Math.round(Math.min(scale.y(0), scale.y(d.size)));
              });
            }
            if (type !== 'column') {
              x$.attr('y', function(d, i){
                return gap / 2 + d.order * (scale.y.bandwidth() - gap) / bars.length;
              });
            }
            if (type !== 'column') {
              x$.attr('height', function(d, i){
                return (scale.y.bandwidth() - gap) / bars.length;
              });
            }
            if (type !== 'column') {
              x$.attr('x', function(d, i){
                return Math.round(Math.min(scale.x(0), scale.x(d.size)));
              });
            }
            return x$;
          }).call(function(sel){
            var x$;
            if (cfg.multiple !== 'stack') {
              return;
            }
            x$ = sel;
            if (type === 'column') {
              x$.attr('x', gap / 2);
            }
            if (type === 'column') {
              x$.attr('width', function(d, i){
                return scale.x.bandwidth() - gap;
              });
            }
            if (type === 'column') {
              x$.attr('y', function(d, i){
                if (d._removing) {
                  return scale.y(d.offset + d.size / 2);
                }
                return Math.round(Math.min(scale.y(d.offset), scale.y(d.offset + d.size)));
              });
            }
            if (type !== 'column') {
              x$.attr('y', gap / 2);
            }
            if (type !== 'column') {
              x$.attr('height', function(d, i){
                return scale.y.bandwidth() - gap;
              });
            }
            if (type !== 'column') {
              x$.attr('x', function(d, i){
                if (d._removing) {
                  return scale.x(d.offset + d.size / 2);
                }
                return Math.round(Math.min(scale.x(d.offset), scale.x(d.offset + d.size)));
              });
            }
            return x$;
          });
          if (type === 'column') {
            tran.attr('height', function(d, i){
              if (d._removing) {
                return 0;
              } else {
                return Math.round(Math.abs(scale.y(0) - scale.y(d.size)));
              }
            });
          } else {
            tran.attr('width', function(d, i){
              if (d._removing) {
                return 0;
              } else {
                return Math.round(Math.abs(scale.x(0) - scale.x(d.size)));
              }
            });
          }
          return tran.attr('fill', function(d, i){
            return tint.get(d.name, cfg.colorVariant ? j / data.length - 0.5 : 0);
          }).attr('fill-opacity', function(d, i){
            var filter, range;
            if (!(binding.name && (filter = binding.name.filter))) {
              return 1;
            }
            if (!(range = filter.value)) {
              return 1;
            }
            if (in$(item.name, range)) {
              return 1;
            } else {
              return 0.2;
            }
          });
        });
        if (this.cfg.brush.enabled) {
          this.g.brush.style.display = 'block';
          this.g.brush.call(this.brush);
        } else {
          this.g.brush.style.display = 'none';
        }
        this.g.brush.selectAll('rect.selection').attr('shape-rendering', 'auto');
        this.legend.render();
        this.yaxis.render();
        return this.xaxis.render();
      },
      tick: function(){}
    };
  };
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
  function in$(x, xs){
    var i = -1, l = xs.length >>> 0;
    while (++i < l) if (x === xs[i]) return true;
    return false;
  }
}).call(this);
