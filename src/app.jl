const IdProp = Tuple{Symbol, Symbol}

const default_index = """<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
    </head>
    <body>
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
    </body>
</html>"""



struct CallbackId
    state ::Vector{IdProp}
    input ::Vector{IdProp}
    output ::Vector{IdProp}    
end

CallbackId(;input ::Union{Vector{IdProp}, IdProp},
            output ::Union{Vector{IdProp}, IdProp},
            state ::Union{Vector{IdProp}, IdProp} = Vector{IdProp}()
            ) = CallbackId(state, input, output)


Base.convert(::Type{Vector{IdProp}}, v::IdProp) = [v]

struct Callback
    func ::Function
    id ::CallbackId
    pass_changed_props ::Bool
end

struct PreventUpdate <: Exception
    
end


struct NoUpdate
end

no_update() = NoUpdate()

mutable struct Layout
    component::Union{Nothing, Component}
end

const ExternalSrcType = Union{String, Dict{String, String}}

struct DashConfig
    external_stylesheets ::Vector{ExternalSrcType}
    external_scripts ::Vector{ExternalSrcType}
    url_base_pathname ::Union{String, Nothing} #TODO This looks unused
    requests_pathname_prefix ::String
    routes_pathname_prefix ::String
    assets_folder ::String
    assets_url_path ::String
    assets_ignore ::String    
    serve_locally ::Bool
    suppress_callback_exceptions ::Bool
    eager_loading ::Bool
    meta_tags ::Vector{Dict{String, String}} 
    index_string ::Union{String, Nothing}
    assets_external_path ::Union{String, Nothing}
    include_assets_files ::Bool
    show_undo_redo ::Bool
end

"""
    struct DashApp <: Any

Representation of Dash application
"""
struct DashApp
    name ::String
    config ::DashConfig
    layout ::Layout
    callbacks ::Dict{Symbol, Callback}
    callable_components ::Dict{Symbol, Component}    
    
    DashApp(name::String, config::DashConfig) = new(name, config, Layout(nothing), Dict{Symbol, Callback}(), Dict{Symbol, Component}())
    
end

function layout!(app::DashApp, component::Component)
    Base.getfield(app, :layout).component = component
    Components.collect_with_ids!(app.layout, app.callable_components)
end

getlayout(app::DashApp) = Base.getfield(app, :layout).component

function Base.setproperty!(app::DashApp, name::Symbol, value)
    name == :layout ? layout!(app, value) : Base.setfield!(app, name, value)
end

function Base.getproperty(app::DashApp, name::Symbol)
    name == :layout ? getlayout(app) : Base.getfield(app, name)
end





"""
    dash(name::String; external_stylesheets ::Vector{String} = Vector{String}(), url_base_pathname::String="/")
    dash(layout_maker::Function, name::String; external_stylesheets ::Vector{String} = Vector{String}(), url_base_pathname::String="/")

Construct a dash app using callback for layout creation

# Arguments
- `layout_maker::Function` - function for layout creation. Must has signature ()::Component
- `name::String` - Dashboard name
- `external_stylesheets::Vector{String} = Vector{String}()` - vector of external css urls 
- `external_scripts::Vector{String} = Vector{String}()` - vector of external js scripts urls 
- `url_base_pathname::String="/"` - base url path for dashboard, default "/" 
- `assets_folder::String` - a path, relative to the current working directory,
for extra files to be used in the browser. Default `"assets"`

# Examples
```jldoctest
julia> app = dash("Test") do
    html_div() do
        html_h1("Test Dashboard")
    end
end
```
"""

function dash(name::String;
        external_stylesheets = ExternalSrcType[],
        external_scripts  = ExternalSrcType[],
        url_base_pathname = nothing,        
        requests_pathname_prefix = nothing,
        routes_pathname_prefix = nothing,
        assets_folder = "assets",
        assets_url_path = "assets",
        assets_ignore = "",        
        serve_locally = true,
        suppress_callback_exceptions = false,
        eager_loading = false, 
        meta_tags = Dict{Symbol, String}[], 
        index_string = default_index, 
        assets_external_path = nothing, 
        include_assets_files = true, 
        show_undo_redo = false

    )
        
       
        config = DashConfig(
            external_stylesheets,
            external_scripts,
            pathname_configs(
                url_base_pathname,                
                requests_pathname_prefix,
                routes_pathname_prefix
                )...,
            absolute_assets_path(assets_folder),
            lstrip(assets_url_path, '/'),
            assets_ignore,             
            serve_locally, 
            suppress_callback_exceptions, 
            eager_loading, 
            meta_tags, 
            index_string, 
            assets_external_path, 
            include_assets_files, 
            show_undo_redo
        )
        
        result = DashApp(name, config)
    return result
end

function dash(layout_maker ::Function, name;
        external_stylesheets = ExternalSrcType[],
        external_scripts  = ExternalSrcType[],
        url_base_pathname = nothing,        
        requests_pathname_prefix = nothing,
        routes_pathname_prefix = nothing,
        assets_folder = "assets",
        assets_url_path = "assets",
        assets_ignore = "",        
        serve_locally = true,
        suppress_callback_exceptions = false,
        eager_loading = false, 
        meta_tags = Dict{Symbol, String}[], 
        index_string = default_index, 
        assets_external_path = nothing, 
        include_assets_files = true, 
        show_undo_redo = false
      )
    result = dash(name,
        external_stylesheets=external_stylesheets,
        external_scripts=external_scripts,
        url_base_pathname=url_base_pathname,
        requests_pathname_prefix = requests_pathname_prefix,
        routes_pathname_prefix = routes_pathname_prefix,
        assets_folder = assets_folder,
        assets_url_path = assets_url_path, 
        assets_ignore = assets_ignore,        
        serve_locally = serve_locally,
        suppress_callback_exceptions = suppress_callback_exceptions,
        eager_loading = eager_loading,
        meta_tags = meta_tags,
        index_string = index_string,
        assets_external_path = assets_external_path,
        include_assets_files = include_assets_files,
        show_undo_redo = show_undo_redo
        )
    layout!(result, layout_maker())
    return result
end



idprop_string(idprop::IdProp) = "$(idprop[1]).$(idprop[2])"

function check_idprop(app::DashApp, id::IdProp)
    if !haskey(app.callable_components, id[1])
        error("The layout havn't component with id `$(id[1])]`")
    end
    if !is_prop_available(app.callable_components[id[1]], id[2])
        error("The component with id `$(id[1])` havn't property `$(id[2])``")
    end
end

function output_string(id::CallbackId)
    if length(id.output) == 1
        return idprop_string(id.output[1])
    end
    return ".." *
    join(map(idprop_string, id.output), "...") *
    ".."
end

"""
    callback!(func::Function, app::Dash, id::CallbackId; pass_changed_props = false)

Create a callback that updates the output by calling function `func`.

If `pass_changed_props` is true then the first argument of callback is an array of changed properties

# Examples

```julia
app = dash("Test") do
    html_div() do
        dcc_input(id="graphTitle", value="Let's Dance!", type = "text"),
        dcc_input(id="graphTitle2", value="Let's Dance!", type = "text"),
        html_div(id="outputID"),
        html_div(id="outputID2")

    end
end
callback!(app, CallbackId(
    state = [(:graphTitle, :type)],
    input = [(:graphTitle, :value)],
    output = [(:outputID, :children), (:outputID2, :children)]
    )
    ) do stateType, inputValue
    return (stateType * "..." * inputValue, inputValue)
end
```

You can use macro `callid` string macro for make CallbackId : 

```julia
callback!(app, callid"{graphTitle.type} graphTitle.value => outputID.children, outputID2.children") do stateType, inputValue

    return (stateType * "..." * inputValue, inputValue)
end
```

Using `changed_props`

```julia
callback!(app, callid"graphTitle.value, graphTitle2.value => outputID.children", pass_changed_props = true) do changed, input1, input2
    if "graphTitle.value" in changed
        return input1
    else
        return input2
    end
end
```

"""
function callback!(func::Function, app::DashApp, id::CallbackId; pass_changed_props = false)    
    
    check_callback(func, app, id, pass_changed_props)
    
    out_symbol = Symbol(output_string(id))
        
    push!(app.callbacks, out_symbol => Callback(func, id, pass_changed_props))
end


function check_callback(func::Function, app::DashApp, id::CallbackId, pass_changed_props)

    

    isempty(id.input) && error("The callback method requires that one or more properly formatted inputs are passed.")

    length(id.output) != length(unique(id.output)) && error("One or more callback outputs have been duplicated; please confirm that all outputs are unique.")

    for out in id.output
        if any(x->out in x.id.output, values(app.callbacks))
            error("output \"$(out)\" already registered")
        end
    end

    foreach(x->check_idprop(app,x), id.state)
    foreach(x->check_idprop(app,x), id.input)
    foreach(x->check_idprop(app,x), id.output)

    args_count = length(id.state) + length(id.input)
    pass_changed_props && (args_count+=1)

    !hasmethod(func, NTuple{args_count, Any}) && error("Callback function don't have method with proper arguments")

    for id_prop in id.input
        id_prop in id.output && error("Circular input and output arguments were found. Please verify that callback outputs are not also input arguments.")
    end
end
