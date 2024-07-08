-- MySQL database dump

-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS sampledata;
USE sampledata;

-- Set character set
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- Disable foreign key checks during import
SET FOREIGN_KEY_CHECKS = 0;

-- Create tables

CREATE TABLE customers (
    customernumber INT,
    customername VARCHAR(50),
    contactlastname VARCHAR(50),
    contactfirstname VARCHAR(50),
    phone VARCHAR(50),
    addressline1 VARCHAR(50),
    addressline2 VARCHAR(50),
    city VARCHAR(50),
    state VARCHAR(50),
    postalcode VARCHAR(15),
    country VARCHAR(50),
    salesrepemployeenumber INT,
    creditlimit DOUBLE
);

CREATE TABLE month_attributes (
    `Month` DOUBLE,
    quarter DOUBLE,
    mth_full_nm VARCHAR(255),
    mth_short_nm VARCHAR(255)
);

CREATE TABLE offices (
    officecode VARCHAR(10),
    city VARCHAR(50),
    phone VARCHAR(50),
    addressline1 VARCHAR(50),
    addressline2 VARCHAR(50),
    state VARCHAR(50),
    country VARCHAR(50),
    postalcode VARCHAR(15),
    territory VARCHAR(10)
);

CREATE TABLE orderdetails (
    ordernumber INT,
    productcode VARCHAR(15),
    quantityordered INT,
    priceeach DOUBLE,
    orderlinenumber SMALLINT
);

CREATE TABLE orderdetails_basic (
    ordernumber INT,
    productcode VARCHAR(15),
    quantityordered INT,
    priceeach DOUBLE,
    orderlinenumber SMALLINT
);

CREATE TABLE orders (
    ordernumber INT,
    orderdate DATETIME,
    requireddate DATETIME,
    shippeddate DATETIME,
    status VARCHAR(15),
    comments TEXT,
    customernumber INT
);

CREATE TABLE orders_basic (
    ordernumber INT,
    orderdate DATETIME,
    requireddate DATETIME,
    shippeddate DATETIME,
    status VARCHAR(15),
    comments TEXT,
    customernumber INT
);

CREATE TABLE payments (
    customernumber INT,
    checknumber VARCHAR(50),
    paymentdate DATETIME,
    amount DOUBLE
);

CREATE TABLE payments_basic (
    customernumber INT,
    checknumber VARCHAR(50),
    paymentdate DATETIME,
    amount DOUBLE
);

CREATE TABLE products (
    productcode VARCHAR(15),
    productname VARCHAR(70),
    productline VARCHAR(50),
    productscale VARCHAR(10),
    productvendor VARCHAR(50),
    productdescription TEXT,
    quantityinstock SMALLINT,
    buyprice DOUBLE,
    msrp DOUBLE
);

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;