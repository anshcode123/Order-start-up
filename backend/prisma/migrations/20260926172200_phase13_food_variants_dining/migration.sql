-- Convert any existing COMPLETED orders to READY before altering OrderStatus enum
UPDATE "orders" SET "status" = 'READY' WHERE "status" = 'COMPLETED';

-- AlterEnum
BEGIN;
CREATE TYPE "OrderStatus_new" AS ENUM ('PENDING', 'ACCEPTED', 'PREPARING', 'READY', 'CANCELLED', 'REJECTED');
ALTER TABLE "orders" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "orders" ALTER COLUMN "status" TYPE "OrderStatus_new" USING ("status"::text::"OrderStatus_new");
ALTER TYPE "OrderStatus" RENAME TO "OrderStatus_old";
ALTER TYPE "OrderStatus_new" RENAME TO "OrderStatus";
DROP TYPE "OrderStatus_old";
ALTER TABLE "orders" ALTER COLUMN "status" SET DEFAULT 'PENDING';
COMMIT;

-- CreateEnum
CREATE TYPE "DiningType" AS ENUM ('DINE_IN', 'TAKEAWAY');

-- AlterTable
ALTER TABLE "restaurants" ADD COLUMN "require_table_number" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "menu_items" ADD COLUMN "has_variants" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "price" SET DEFAULT 0;

-- AlterTable
ALTER TABLE "orders" ADD COLUMN "dining_type" "DiningType" NOT NULL DEFAULT 'DINE_IN',
ALTER COLUMN "table_number" DROP NOT NULL;

-- AlterTable
ALTER TABLE "order_items" ADD COLUMN "variant_id" TEXT,
ADD COLUMN "variant_name" TEXT;

-- CreateTable
CREATE TABLE "menu_item_variants" (
    "id" TEXT NOT NULL,
    "menu_item_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "price" DECIMAL(10,2) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_available" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "menu_item_variants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "menu_item_variants_menu_item_id_idx" ON "menu_item_variants"("menu_item_id");

-- CreateIndex
CREATE UNIQUE INDEX "menu_item_variants_menu_item_id_name_key" ON "menu_item_variants"("menu_item_id", "name");

-- AddForeignKey
ALTER TABLE "menu_item_variants" ADD CONSTRAINT "menu_item_variants_menu_item_id_fkey" FOREIGN KEY ("menu_item_id") REFERENCES "menu_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;
