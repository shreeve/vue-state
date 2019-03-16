import Vue from 'vue'

num = (val) -> /^-?(\d+)$/.test val
kind = (obj) -> if obj? then (obj.constructor?.name or Object::toString.call(obj)[8...-1]) else String(obj)
regx = /([.\/][^.\/\[\<\s]+|\[[-+]?\d+\]|\[(?:"[^"]+"|'[^']+')\])/

get = (state, path, valu) ->
  list = walk path
  for prop in list
    return valu unless state? and typeof state is 'object'
    prop = state.length + prop if num(prop) and Array.isArray(state) and +prop < 0
    state = state[prop]
  # if state? then state else valu # non-Vue version
  if state? and cls = kind(state)
    if cls is 'Vue' or cls is 'VueComponent'
      if path is '/'
        out = {}
        for name, nest of vue state
          cls = kind(nest)
          out[name] = if cls is 'Vue' or cls is 'VueComponent' then vue(nest) else nest
        out
      else vue state
    else state
  else valu

set = (state, path, valu) ->
  state = state.$data # Vue-specific, only $data is settable
  list = walk path
  last = list.length - 1
  for prop, slot in list
    if slot is last
      next = valu
    else
      prop = state.length + prop if num(prop) and Array.isArray(state) and +prop < 0
      next = if state.hasOwnProperty prop then state[prop] else undefined
      next ?= undefined
      next = (if num(list[slot+1]) then [] else {}) if typeof next isnt 'object'
    # state = state[prop] = next # non-Vue version
    state = Vue.set state, prop, next
  state

inc = (state, path, step=1, init=0) ->
  list = walk path
  last = list.length - 1
  for prop, slot in list
    if slot is last
      next = state[prop] if state.hasOwnProperty prop
      next = if num(next) then next + step else init
    else
      prop = state.length + prop if num(prop) and Array.isArray(state) and +prop < 0
      next = if state.hasOwnProperty prop then state[prop] else undefined
      next ?= undefined
      next = (if num(list[slot+1]) then [] else {}) if typeof next isnt 'object'
    # state = state[prop] = next # non-Vue version
    state = Vue.set state, prop, next
  state

run = (state, path, args...) ->
  return fn.call state, args... if typeof(fn = get state, path) is 'function'
  console.warn "undefined function #{path}"
  return

walk = (path) ->
  list = ('.' + path).split regx; list.shift()
  for part in list by 2
    switch chr = part[0]
      when '.', '/' then part.slice 1
      when '['
        if part[1] is '"' or part[1] is "'" then part.slice 2, -2
        else +(part.slice 1, -1)
      else continue

vue = (state) ->
  computed = {}
  computed[k] = v.call(state) for k, v of state.$options.computed
  Object.assign {}, state.$props, state.$data, computed

export default VueState =
  install: (Vue, options) ->
    state = (Vue.observable '/': (options?.state or {}))['/']
    state.get = Vue::get = (args...) -> get((if args[0][0] is '/' then state else @), args...)
    state.set = Vue::set = (args...) -> set((if args[0][0] is '/' then state else @), args...)
    state.inc = Vue::inc = (args...) -> inc((if args[0][0] is '/' then state else @), args...)
    state.run = Vue::run = (args...) -> run((if args[0][0] is '/' then state else @), args...)
    window[options.global] = state if options?.global
