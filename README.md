# pikin

A lambda function for pikin by marcstreeterdev

## Project Structure

### Prerequisites

- [brew](https://brew.sh) helps install tools
- [asdf](https://asdf-vm.com/) with Python and Poetry plugins (install with `brew install asdf`[*](https://asdf-vm.com/guide/getting-started.html#_1-install-asdf))
- [Docker](https://www.docker.com/)
- [Tilt](https://tilt.dev/) for local development
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured with docker-desktop context
- [just](https://just.systems) performs all steps (install with `brew install just`[*](https://just.systems/man/en/packages.html#cross-platform))

### Setup

Review available commands here:

```bash
just
```


## Workflow

1. **Setup Environment**: Consult `just` command (it sets up lambda/dynamodb/github)
2. **Infrastructure**: Make code changes to `src/` directory (can use Tilt to make local iterations)
3. **Code Deployment**: GitHub Actions automatically deploys code changes to lambda


### Getting Help

- Run `just` for available commands
- Review CloudWatch logs for Lambda function issues


## Portability

This project is designed to be portable but you must fill in `.env` (`.env.example` provided) file with your details.

## Testing

### Send Valid Request
There a couple ways to test a running copy of the local lambda:

```http
POST http://localhost:18010/2015-03-31/functions/function/invocations
Content-Type: application/json
{
  "rsvp_total": 2,
  "rsvp_name": "From PyCharm With Love"
}
```

You can also run test payloads locally using Tilt's "interface" endpoint when running:
```
just dev
```
