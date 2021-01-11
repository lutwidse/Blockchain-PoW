## Do you wanna tie up someone with the chain huh?

 - API

   - Add new transaction to the current transactions : http://127.0.0.1:port/transactions/new
     - POST
{
    "sender": "Alice",
    "recipient": "Bob",
    "amount": "1"
}

   - Mining : http://127.0.0.1:port/mine - GET

   - Get a chain from full-nodes : http://127.0.0.1:port/fullchain - GET

   - Register nodes : http://127.0.0.1:port/nodes/register
     - POST
{
    "nodes": ["http://127.0.0.1:port/"]
}

   - Resolve consensus conflicts : http://127.0.0.1:port/nodes/resolve_consensus - GET

   - Ping Pong : http://127.0.0.1:port/nodes/ping - GET
***
- Example

  - 1 . Run Blockchain.jl on port 4000 and 8000

  - 2 . http://127.0.0.1:port/nodes/register
    - POST
{
    "nodes": ["http://127.0.0.1:4000/"]
}

  - 3 . http://127.0.0.1:8000/mine

  - 4 . http://127.0.0.1:4000/nodes/resolve_consensus

  - 5 . http://127.0.0.1:4000/fullchain

  - 6 . Success if the chain has been updated
