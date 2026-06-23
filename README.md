# Add, edit or exclude NFT Collection

To add or edit NFT collection go to `config.rb` and edit this `COLLECTIONS = ['mash-it']`

And to exclude sales and listing message from just a NFT from the collection just add NFT name here:
`  EXCLUDED_NFTS = [
    'Jay and pets'
  ].map(&:downcase)
`
