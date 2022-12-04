json.extract! transaction, :id, :kind_of, :wallet_id, :created_at, :updated_at
json.url transaction_url(transaction, format: :json)
