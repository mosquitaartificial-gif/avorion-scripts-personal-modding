
-- The existing UUIDs should NOT be changed
-- if you do the command will be assumed as if it's a new one and existing ships will stop the old command
-- the order of the commands in the table doesn't matter, feel free to sort/organize
-- UUIDs were generated using https://www.uuidgenerator.net/ (Version 4 UUID)
local CommandType =
{
    Prototype = "75381938-0832-4be6-8d36-c3f1e9fce679", -- this is for development purposes only

    Travel = "bbcf8ba1-a1e0-4a34-8174-15caebd11fed",
    Scout = "7619ca9c-3f26-4b89-a4a4-10fd9aca5c60",

    Mine = "c367bdbc-15c1-4aac-b691-cf92b6c541a0",
    Salvage = "1cbc94e6-aea3-4d1f-8159-d9e27d6b5d92",
    Refine = "77110b44-b327-4747-b618-69a82a5789cf",

    Trade = "0c21be5b-d6a9-47ca-a1b3-200b11d2af4b",
    Procure = "c2f0d06e-1a0b-490e-b2f1-e72f2c75a9db",
    Sell = "6bf2d9af-255b-4108-a1e1-dc83ace49819",
    Supply = "94f687f6-70b7-4491-afa5-99932a626be3",

    Expedition = "3b881819-3eb6-4af0-b4d3-a24558162432",
    Maintenance = "d1a1b62f-6f58-43fa-93c0-3a0926a666af",

    Escort = "4c9331c4-1634-4aaf-b1c6-1b9d38ddefde",
}

return CommandType
