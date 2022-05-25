#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
require("source-map-support/register");
const cdk = require("aws-cdk-lib");
const pg_vpc_stack_1 = require("../lib/pg-vpc-stack");
const pg_rds_stack_1 = require("../lib/pg-rds-stack");
const constructs_1 = require("constructs");
class RdsPgApp extends constructs_1.Construct {
    constructor(scope, id) {
        super(scope, id);
        const vpcStack = new pg_vpc_stack_1.PgVpcStack(app, 'PgVpcStack', {
            env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
            cidr: '10.0.0.0/16',
        });
        new pg_rds_stack_1.PgRdsStack(app, 'PgRdsStack', {
            env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },
            vpc: vpcStack.vpc,
            stage: id
        });
    }
}
const app = new cdk.App();
new RdsPgApp(app, 'dev');
//# sourceMappingURL=data:application/json;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoicGctdnBjLmpzIiwic291cmNlUm9vdCI6IiIsInNvdXJjZXMiOlsicGctdnBjLnRzIl0sIm5hbWVzIjpbXSwibWFwcGluZ3MiOiI7OztBQUNBLHVDQUFxQztBQUNyQyxtQ0FBbUM7QUFDbkMsc0RBQWlEO0FBQ2pELHNEQUFpRDtBQUNqRCwyQ0FBdUM7QUFHdkMsTUFBTSxRQUFTLFNBQVEsc0JBQVM7SUFDOUIsWUFBWSxLQUFjLEVBQUUsRUFBUztRQUNuQyxLQUFLLENBQUMsS0FBSyxFQUFFLEVBQUUsQ0FBQyxDQUFDO1FBRWpCLE1BQU0sUUFBUSxHQUFHLElBQUkseUJBQVUsQ0FBQyxHQUFHLEVBQUUsWUFBWSxFQUFFO1lBQ2pELEdBQUcsRUFBRSxFQUFFLE9BQU8sRUFBRSxPQUFPLENBQUMsR0FBRyxDQUFDLG1CQUFtQixFQUFFLE1BQU0sRUFBRSxPQUFPLENBQUMsR0FBRyxDQUFDLGtCQUFrQixFQUFFO1lBQ3pGLElBQUksRUFBRSxhQUFhO1NBQ3BCLENBQUMsQ0FBQztRQUNILElBQUkseUJBQVUsQ0FBQyxHQUFHLEVBQUUsWUFBWSxFQUFFO1lBQ2hDLEdBQUcsRUFBRSxFQUFFLE9BQU8sRUFBRSxPQUFPLENBQUMsR0FBRyxDQUFDLG1CQUFtQixFQUFFLE1BQU0sRUFBRSxPQUFPLENBQUMsR0FBRyxDQUFDLGtCQUFrQixFQUFFO1lBQ3pGLEdBQUcsRUFBRSxRQUFRLENBQUMsR0FBRztZQUNqQixLQUFLLEVBQUUsRUFBRTtTQUNWLENBQUMsQ0FBQztJQUVMLENBQUM7Q0FFRjtBQUVELE1BQU0sR0FBRyxHQUFHLElBQUksR0FBRyxDQUFDLEdBQUcsRUFBRSxDQUFDO0FBQzFCLElBQUksUUFBUSxDQUFDLEdBQUcsRUFBRSxLQUFLLENBQUMsQ0FBQyIsInNvdXJjZXNDb250ZW50IjpbIiMhL3Vzci9iaW4vZW52IG5vZGVcbmltcG9ydCAnc291cmNlLW1hcC1zdXBwb3J0L3JlZ2lzdGVyJztcbmltcG9ydCAqIGFzIGNkayBmcm9tICdhd3MtY2RrLWxpYic7XG5pbXBvcnQgeyBQZ1ZwY1N0YWNrIH0gZnJvbSAnLi4vbGliL3BnLXZwYy1zdGFjayc7XG5pbXBvcnQgeyBQZ1Jkc1N0YWNrIH0gZnJvbSAnLi4vbGliL3BnLXJkcy1zdGFjayc7XG5pbXBvcnQgeyBDb25zdHJ1Y3QgfSBmcm9tICdjb25zdHJ1Y3RzJztcblxuXG5jbGFzcyBSZHNQZ0FwcCBleHRlbmRzIENvbnN0cnVjdCB7XG4gIGNvbnN0cnVjdG9yKHNjb3BlOiBjZGsuQXBwLCBpZDpzdHJpbmcpe1xuICAgIHN1cGVyKHNjb3BlLCBpZCk7XG5cbiAgICBjb25zdCB2cGNTdGFjayA9IG5ldyBQZ1ZwY1N0YWNrKGFwcCwgJ1BnVnBjU3RhY2snLCB7XG4gICAgICBlbnY6IHsgYWNjb3VudDogcHJvY2Vzcy5lbnYuQ0RLX0RFRkFVTFRfQUNDT1VOVCwgcmVnaW9uOiBwcm9jZXNzLmVudi5DREtfREVGQVVMVF9SRUdJT04gfSxcbiAgICAgIGNpZHI6ICcxMC4wLjAuMC8xNicsXG4gICAgfSk7XG4gICAgbmV3IFBnUmRzU3RhY2soYXBwLCAnUGdSZHNTdGFjaycsIHtcbiAgICAgIGVudjogeyBhY2NvdW50OiBwcm9jZXNzLmVudi5DREtfREVGQVVMVF9BQ0NPVU5ULCByZWdpb246IHByb2Nlc3MuZW52LkNES19ERUZBVUxUX1JFR0lPTiB9LFxuICAgICAgdnBjOiB2cGNTdGFjay52cGMsXG4gICAgICBzdGFnZTogaWRcbiAgICB9KTtcblxuICB9XG5cbn1cblxuY29uc3QgYXBwID0gbmV3IGNkay5BcHAoKTtcbm5ldyBSZHNQZ0FwcChhcHAsICdkZXYnKTtcblxuIl19