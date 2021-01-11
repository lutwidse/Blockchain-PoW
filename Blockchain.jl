using Dates
using SHA, UUIDs, Random
using Genie, Genie.Router, Genie.Requests
using JSON, HTTP
using DataStructures
using URIs

mutable struct Blockchain
    chain::Array
    current_transactions::Array
    nodes::Set
end

function generate_genesis_block(bc::Blockchain)
    println("[BLOCKCHAIN] > ", "Initializing chain")
    generate_block(bc, 10, "1")
    println("[BLOCKCHAIN] > ", "Genesis block has been generated")
    JSON.print(stdout, bc.chain[end], 4)
    println()
end

function generate_block(bc::Blockchain, nonce::Int, prev_hash::String)
    #=
    nonce - PoW's
    prev_hash - Previous block's hash
    =#

    block = Dict(
    "index" => size(bc.chain)[1] + 1,
    "timestamp" => get_timestamp(),
    "transactions" => bc.current_transactions,
    "nonce" => nonce,
    "previous_hash" => !(isnothing(prev_hash)) ? prev_hash : hash_block(bc.chain[end])
    )

    bc.current_transactions = []
    println("[BLOCKCHAIN] > ", "Cleared current transactions")

    push!(bc.chain, block)
    println("[BLOCKCHAIN] > ", "Added new block to the chain")
    JSON.print(stdout, bc.chain[end], 4)
    println()

    return block
end

function generate_transaction(bc::Blockchain, sender::String, recipient::String, amount::Int)
    #=
    sender - Alice
    recipient - Bob
    amount - e.g. 0.01 btc
    =#

    transaction = Dict(
    "sender" => sender,
    "recipient" => recipient,
    "amount" => amount
    )
    push!(bc.current_transactions, transaction)
    println("[BLOCKCHAIN] > ", "Added new transaction to current transactions ")
    JSON.print(stdout, transaction, 4)
    println()

    # Get this address to identify the block
    return get_end_block()["index"] + 1
end

function hash_block(block::Dict)
    #= SHA-256 Hashed block
       Mmm... Yummy! =#
    block_str = JSON.json(SortedDict(block))
    return bytes2hex(sha256(block_str))
end

function get_end_block()
    return bc.chain[end]
end

function pow(bc::Blockchain, end_block::Dict)

    prev_hash = hash_block(end_block)
    end_nonce = end_block["nonce"]
    nonce = 0

    start = get_timestamp()
    hashrate = 0
    secs = 10
    while validate_nonce(end_nonce, nonce, prev_hash) != true
        if (elapsed_time = get_timestamp() - start >= secs)
            hashrate_sec = round(Int64, hashrate / secs)
            if (hashrate_sec >= 1000) println("[MINING] > ", hashrate_sec / 1000, " KH/s") else println("[MINING] > ", hashrate_sec, " H/s") end
            println()
            start = get_timestamp()
            hashrate = 0
        end
        nonce += 1
        hashrate += 1
    end

    return nonce
end

function validate_nonce(end_nonce::Int, nonce::Int, prev_hash::String)
    # n * n prime * previous hash
    nnp = string(end_nonce) * string(nonce) * prev_hash
    nnp_hash = bytes2hex(sha256(nnp))

    if (first(nnp_hash, 6) == "2021ab")
        println("[MINING] > ", "Found correct nonce => $nonce => ", nnp_hash)
        println()
    end

    # Valid if first n letters are correct as keys, it used for mining difficulty
    return first(nnp_hash, 6) == "2021ab"
end

function validate_chain(chain::Array)
    end_block = chain[1]
    current_index = 2

    while current_index < length(chain)
        block = chain[current_index]

        end_block_hash = hash_block(end_block)
        if block["previous_hash"] != end_block_hash
            println("[BLOCKCHAIN] > ", "Invalid block hash")
            println()
            return false
        end

        if !(validate_nonce(end_block["nonce"], block["nonce"], end_block_hash))
            println("[BLOCKCHAIN] > ", "Invalid PoW")
            println()
            return false
        end

        end_block = block
        current_index += 1
    end

    return true
end

function register_node(bc::Blockchain, address::String)
    #=
    address - e.g. http://192.168.1.2:12345/
    =#

    network = !isnothing(URI(address).port) ? URI(address).host * ":" * URI(address).port : URI(address).host
    push!(bc.nodes, network)
end

function resolve_conflicts(bc::Blockchain)
    networks = bc.nodes
    next_chain = nothing

    max_len = length(bc.chain)

    for node in networks
        resp = HTTP.request("GET", "http://$node/fullchain")
        if resp.status == 200
            resp_json = JSON.parse(String(resp.body))
            len = resp_json["length"]
            chain = resp_json["chain"]

            # The King Must Be Oh Long Johnson
            if len > max_len && validate_chain(chain)
                max_len = len
                next_chain = chain
            end
        end
    end

    # Replace chain if valid
    if !isnothing(next_chain)
        bc.chain = next_chain
        println("[BLOCKCHAIN] > ", "Chain has been updated")
        println()
        return true
    end

    return false
end

@async function resolve_dead_node()
    networks = bc.nodes

    for node in networks

        # You must do try-catch DNSError for dead node
        resp = HTTP.request("GET", "http://$node/nodes/ping")
        if resp.status != 200
            delete!(bc.nodes, node)
            println("[NODES] > ", "Removed dead node from nodes")
            println()
        end
    end
end

function get_timestamp()
    return floor(Int64,(Dates.datetime2unix(Dates.now())))
end

println("...")

bc = Blockchain([], [], Set())

generate_genesis_block(bc)

# Unique Id
rng = MersenneTwister(2021);
unencrypted_address = replace(string(uuid4(rng)), "-" => "")

println("[BLOCKCHAIN] > ", "Unencrypted Address => $unencrypted_address")
println()

# API
route("/transactions/new", method = POST) do
    keys = jsonpayload()

    if (isnothing(keys))
        resp = Dict(
        "status_code" => "500",
        "message" => "Invalid JSON"
        )

        return (resp) |> json
    end

    idx = generate_transaction(bc, keys["sender"], keys["recipient"], keys["amount"])
    resp = Dict(
    "status_code" => "201",
    "message" => "The Transaction has been added to block #$idx"
    )

    return (resp) |> json
end

route("/mine", method = GET) do
    # PoW
    end_block = get_end_block()
    end_nonce = end_block["nonce"]
    prev_hash = hash_block(end_block)

    println("[MINING] > ", "Lets get some golden K*C nuggets...")
    println()

    nonce = pow(bc, end_block)

    # Mining Reward
    generate_transaction(bc, "REWARD", unencrypted_address, 1)

    println("[MINING] > ", "Mining Reward has been added to the transactions")
    println

    block = generate_block(bc, nonce, prev_hash)

    resp = JSON.json(Dict(
    "index" => block["index"],
    "timestamp" => block["timestamp"],
    "transactions" => block["transactions"],
    "nonce" => block["nonce"],
    "previous_hash" => block["previous_hash"]
    ))

    return resp
end

route("/fullchain", method = GET) do
    resp = JSON.json(Dict(
    "chain" => bc.chain,
    "length" => length(bc.chain)
    ))

    return resp
end

route("/nodes/register", method = POST) do
    keys = jsonpayload()

    if (isnothing(keys))
        resp = Dict(
        "status_code" => "500",
        "message" => "Invalid JSON"
        )

        return (resp) |> json
    end

    function fill_node_keys!(node)
        for node in keys["nodes"]
            register_node(bc, node)
        end
    end

    node = ""
    fill_node_keys!(node)

    resp = JSON.json(Dict(
    "status_code" => "201",
    "message" => "New node has been added",
    "numbers_of_node" => length(bc.nodes),
    "nodes" => collect(bc.nodes)
    ))

    return resp
end

route("/nodes/resolve_consensus", method = GET) do
    replaced = resolve_conflicts(bc)

    if replaced
        resp = JSON.json(Dict(
        "status_code" => "200",
        "message" => "The chain has been replaced",
        "next_chain" => bc.chain
        ))
        return resp

    else
        resp = JSON.json(Dict(
        "status_code" => "200",
        "message" => "The chain has been confirmed",
        "chain" => bc.chain
        ))
        return resp
    end
end

route("/nodes/ping", method = GET) do
    resp = JSON.json(Dict(
    "pong" => "Hempel's ravens",
    ))

    return resp
end

Genie.startup(8000, "127.0.0.1", async = false)
