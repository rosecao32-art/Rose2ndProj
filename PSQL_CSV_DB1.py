import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.dialects.postgresql import insert
from datetime import datetime

# ---------------------------------------------------------
# 1. CONNECT TO POSTGRESQL
# ---------------------------------------------------------
engine = create_engine(
    "postgresql+psycopg2://pgrose:Xcfcyq32@localhost:5432/pgrose_db"
)

print("Connected to PostgreSQL!")


# ---------------------------------------------------------
# 2. EXTRACT — Load raw CSV
# ---------------------------------------------------------
df = pd.read_csv("raw_sales.csv")

# Normalize column names
df.columns = df.columns.str.lower().str.strip()


# ---------------------------------------------------------
# 3. TRANSFORM — Clean raw data
# ---------------------------------------------------------

# Convert numeric fields
df["price"] = pd.to_numeric(df["price"], errors="coerce")
df["quantity"] = pd.to_numeric(df["quantity"], errors="coerce")

# Remove invalid numeric rows
df = df.dropna(subset=["price", "quantity"])
df = df[df["price"] > 0]
df = df[df["quantity"] > 0]

# Convert dates
df["order_date"] = pd.to_datetime(df["order_date"], errors="coerce")
df = df.dropna(subset=["order_date"])

# Compute total amount
df["total_amount"] = df["price"] * df["quantity"]


# ---------------------------------------------------------
# 4. LOAD DIMENSIONS — Read dimension tables
# ---------------------------------------------------------
dim_customers = pd.read_sql("SELECT * FROM dim_customer;", engine)
dim_products  = pd.read_sql("SELECT * FROM dim_product;", engine)
dim_date      = pd.read_sql("SELECT * FROM dim_date;", engine)


# ---------------------------------------------------------
# 5. LOOKUP KEYS — Map raw CSV to dimension surrogate keys
# ---------------------------------------------------------

# CUSTOMER KEY
df = df.merge(
    dim_customers[["customer_key", "customer_id"]],
    on="customer_id",
    how="left"
)

# PRODUCT KEY
df = df.merge(
    dim_products[["product_key", "product_id"]],
    on="product_id",
    how="left"
)

dim_date["full_date"] = pd.to_datetime(dim_date["full_date"], errors="coerce")
# DATE KEY
df = df.merge(
    dim_date[["date_key", "full_date"]],
    left_on="order_date",
    right_on="full_date",
    how="left"
)


customers = df[["customer_id"]].drop_duplicates()
customers["name"] = customers["customer_id"].apply(lambda x: f"Customer {x}")
customers["email"] = customers["customer_id"].apply(lambda x: f"customer{x}@example.com")

stmt = insert(customers).values(customers.to_dict(orient="records"))
stmt = stmt.on_conflict_do_nothing(index_elements=["customer_id"])

with engine.begin() as conn:
    conn.execute(stmt)


# ---------------------------------------------------------
# 6. BUILD FACT TABLE — fact_sales
# ---------------------------------------------------------
fact_sales = df[[
    "customer_key",
    "product_key",
    "date_key",
    "quantity",
    "total_amount"
]]

fact_sales.to_sql(
    "fact_sales",
    engine,
    if_exists="append",
    index=False
)

print("fact_sales updated!")


# ---------------------------------------------------------
# 7. BUILD SUMMARY TABLE — fact_sales_summary
# ---------------------------------------------------------
fact_summary = df.groupby("product_key").agg(
    total_quantity=("quantity", "sum"),
    total_sales=("total_amount", "sum")
).reset_index()

fact_summary.to_sql(
    "fact_sales_summary",
    engine,
    if_exists="append",
    index=False
)

print("fact_sales_summary updated!")


# ---------------------------------------------------------
# 8. BUILD ORDER TOTALS TABLE — order_totals
# ---------------------------------------------------------
order_totals = df.groupby("order_id").agg(
    total_amount=("total_amount", "sum")
).reset_index()

order_totals.to_sql(
    "total_amount",
    engine,
    if_exists="append",
    index=False
)

print("order_totals updated!")


# ---------------------------------------------------------
# 9. BUILD ORDERS TABLE — orders
# ---------------------------------------------------------
orders = df[[
    "order_id",
    "customer_id",
    "quantity",
    "order_date",
    "total_amount"
]]

orders.to_sql(
    "orders",
    engine,
    if_exists="append",
    index=False
)

print("orders updated!")


product_master = df[["product_id"]].drop_duplicates()
product_master["name"] = product_master["product_id"].apply(lambda x: f"Product {x}")
product_master["price"] = 0  # or lookup real price

product_master.to_sql("products", engine, if_exists="append", index=False)

print("products updated!")


# ---------------------------------------------------------
# 10. BUILD PRODUCTS TABLE — products
# ---------------------------------------------------------
products = df.groupby("product_id").agg(
    avg_price=("price", "mean"),
    total_sold=("quantity", "sum")
).reset_index()

products.to_sql(
    "product_sales_summary",
    engine,
    if_exists="append",
    index=False
)

print("product_sales_summary updated!")

print("ETL COMPLETE!")
