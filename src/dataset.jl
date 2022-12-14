using DrWatson
@quickactivate

using JsonGrinder
using JSON
using Mill
using ThreadTools
using BSON
using CSV, DataFrames
using ProgressMeter

const datapath = "/mnt/data/jsonlearning/Avast_cockoo"
const datapath_full = "/mnt/data/jsonlearning/Avast_cuckoo_full"
read_json(file) = JSON.parse(read(file, String))

# dataset structure
struct Dataset
    samples
    family
    type
    date
    schema
    extractor
end

function Dataset(full=false)
    if full
        df = CSV.read("$datapath_full/public_labels.csv", DataFrame)
        sch = BSON.load(datadir("schema_full.bson"))[:schema]
    else
        df = CSV.read("$datapath/public_labels.csv", DataFrame)
        sch = BSON.load(datadir("schema.bson"))[:schema]
    end
    extractor = suggestextractor(sch)

    Dataset(
        Vector(df.sha256),
        String.(df.classification_family),
        String.(df.classification_type),
        Vector(df.date),
        schema,
        extractor
    )
end

# this is too slow
# function Base.getindex(d::Dataset, inds)
#     files = joinpath.(datapath, "public_small_reports", string.(d.samples[inds], ".json"))
#     data = reduce(catobs, tmap(x -> extractor(read_json(x)), files))
#     type, family, date = d.type[inds], d.family[inds], d.date[inds]
#     return data, type, family, date
# end

function Base.getindex(d::Dataset, inds)
    files = joinpath.(datapath, "public_small_reports", string.(d.samples[inds], ".json"))
    data = load_samples(d; inds=inds)
    # type, family, date = d.type[inds], d.family[inds], d.date[inds]
    family = d.family[inds]
    # return data, type, family, date
    return data, family
end

# load samples
function load_samples(d::Dataset; inds = :)
    files = joinpath.(datapath, "public_small_reports", string.(d.samples[inds], ".json"))
    n = length(files)
    dicts = Vector{ProductNode}(undef, n)

    if typeof(inds) == Colon || length(inds) > 128
        p = Progress(n; desc="Extracting JSONs: ")
        Threads.@threads for i in 1:n
            dicts[i] = d.extractor(read_json(files[i]))
            next!(p)
        end
    else
        for i in 1:n
            dicts[i] = d.extractor(read_json(files[i]))
        end
    end
    return reduce(catobs, dicts)
end

# d = Dataset()
# @time d[1:20000]